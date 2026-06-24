const express = require('express');
const { Pool } = require('pg');
const path = require('path');
const dotenv = require('dotenv');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const fs = require('fs');

dotenv.config({ path: path.join(__dirname, '.env') });
const secret = process.env.JWT_SECRET;
if (!secret) {
  console.error('❌ FATAL: JWT_SECRET environment variable is not set!');
  process.exit(1);
}
const app = express();

// Middleware
app.use(cors({
  origin: function (origin, callback) {
    if (!origin) return callback(null, true);
    if (origin.match(/^http:\/\/localhost(:\d+)?$/) ||
      origin.match(/^http:\/\/127\.0\.0\.1(:\d+)?$/)) {
      return callback(null, true);
    }
    callback(null, true);
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Bypass-Tunnel-Reminder'],
  credentials: true
}));
app.use(express.json());
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  // NOTE: Never log request bodies — they may contain passwords/tokens
  next();
});
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// =====================
// POSTGRESQL DATABASE SETUP (NEON)
// =====================

if (!process.env.DATABASE_URL) {
  console.error('❌ FATAL: DATABASE_URL environment variable is not set!');
  process.exit(1);
}

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

// Helper: run a query
async function query(text, params) {
  const client = await pool.connect();
  try {
    const result = await client.query(text, params);
    return result;
  } finally {
    client.release();
  }
}

// Helper: generate ID
function generateId() {
  return 'id_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
}

// =====================
// AUTH MIDDLEWARE
// =====================
async function authenticateToken(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader && authHeader.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token provided' });

    const decoded = jwt.verify(token, secret);
    // Attach role from token; also fetch from DB to ensure user still exists
    const result = await query(`SELECT id, role, name, email, username FROM users WHERE id = $1`, [decoded.userId]);
    if (result.rows.length === 0) return res.status(401).json({ success: false, message: 'User not found' });

    req.user = { ...decoded, ...result.rows[0], userId: result.rows[0].id };
    next();
  } catch (err) {
    return res.status(401).json({ success: false, message: 'Invalid or expired token' });
  }
}

async function initDB() {
  try {
    await query(`
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        "passwordHash" TEXT NOT NULL,
        role TEXT NOT NULL,
        "className" TEXT,
        section TEXT,
        specialization TEXT,
        college TEXT,
        phone TEXT,
        "deletedAt" TEXT,
        "createdAt" TEXT DEFAULT CURRENT_TIMESTAMP
      );

      ALTER TABLE users ADD COLUMN IF NOT EXISTS "deletedAt" TEXT;

      CREATE TABLE IF NOT EXISTS lectures (
        id TEXT PRIMARY KEY,
        "subjectName" TEXT NOT NULL,
        "teacherName" TEXT NOT NULL,
        "className" TEXT NOT NULL,
        section TEXT,
        specialization TEXT,
        college TEXT,
        "startTime" TEXT NOT NULL,
        "endTime" TEXT NOT NULL,
        "roomNumber" TEXT,
        "lectureDate" TEXT NOT NULL,
        "isCancelled" INTEGER DEFAULT 0,
        "cancellationReason" TEXT,
        "createdAt" TEXT DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS notifications (
        id TEXT PRIMARY KEY,
        "studentId" TEXT NOT NULL,
        "lectureId" TEXT,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        "notificationType" TEXT,
        "isRead" INTEGER DEFAULT 0,
        "scheduledAt" TEXT DEFAULT CURRENT_TIMESTAMP,
        "createdAt" TEXT DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS timetable (
        id TEXT PRIMARY KEY,
        "subjectName" TEXT NOT NULL,
        "teacherName" TEXT NOT NULL,
        "className" TEXT NOT NULL,
        section TEXT,
        specialization TEXT,
        college TEXT,
        day TEXT NOT NULL,
        "startTime" TEXT NOT NULL,
        "endTime" TEXT NOT NULL,
        "roomNumber" TEXT,
        "createdAt" TEXT DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // Alter tables to add columns if they already exist without them
    await query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS username TEXT UNIQUE`);
    await query(`ALTER TABLE users ALTER COLUMN email DROP NOT NULL`);
    await query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS specialization TEXT`);
    await query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS college TEXT`);
    await query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS phone TEXT`);
    await query(`ALTER TABLE lectures ADD COLUMN IF NOT EXISTS specialization TEXT`);
    await query(`ALTER TABLE lectures ADD COLUMN IF NOT EXISTS college TEXT`);
    await query(`ALTER TABLE timetable ADD COLUMN IF NOT EXISTS specialization TEXT`);
    await query(`ALTER TABLE timetable ADD COLUMN IF NOT EXISTS college TEXT`);

    // Online Tests tables
    await query(`
      CREATE TABLE IF NOT EXISTS online_tests (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        instructions TEXT,
        "className" TEXT NOT NULL,
        section TEXT,
        "durationMinutes" INTEGER NOT NULL DEFAULT 30,
        "teacherId" TEXT NOT NULL,
        "teacherName" TEXT NOT NULL,
        "createdAt" TEXT DEFAULT CURRENT_TIMESTAMP
      );
    `);
    await query(`
      CREATE TABLE IF NOT EXISTS test_questions (
        id TEXT PRIMARY KEY,
        "testId" TEXT NOT NULL REFERENCES online_tests(id) ON DELETE CASCADE,
        "questionText" TEXT NOT NULL,
        options TEXT NOT NULL,
        "correctOptionIndex" INTEGER NOT NULL
      );
    `);
    await query(`
      CREATE TABLE IF NOT EXISTS test_attempts (
        id TEXT PRIMARY KEY,
        "testId" TEXT NOT NULL,
        "studentId" TEXT NOT NULL,
        "studentName" TEXT NOT NULL,
        score INTEGER NOT NULL,
        "totalQuestions" INTEGER NOT NULL,
        "completedAt" TEXT DEFAULT CURRENT_TIMESTAMP,
        UNIQUE("testId", "studentId")
      );
    `);

    await query(`ALTER TABLE online_tests ADD COLUMN IF NOT EXISTS specialization TEXT`);

    // Study Materials Hub
    await query(`
      CREATE TABLE IF NOT EXISTS study_materials (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        "fileUrl" TEXT NOT NULL,
        "fileName" TEXT NOT NULL,
        "fileType" TEXT,
        "className" TEXT NOT NULL,
        section TEXT,
        specialization TEXT,
        college TEXT,
        "teacherId" TEXT NOT NULL,
        "teacherName" TEXT NOT NULL,
        "createdAt" TEXT DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // Messaging System
    await query(`
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        "senderId" TEXT NOT NULL,
        "receiverId" TEXT NOT NULL,
        content TEXT NOT NULL,
        "isRead" INTEGER DEFAULT 0,
        "createdAt" TEXT DEFAULT CURRENT_TIMESTAMP
      );
    `);

    await query(`
      CREATE TABLE IF NOT EXISTS blocked_users (
        id TEXT PRIMARY KEY,
        "blockerId" TEXT NOT NULL,
        "blockedId" TEXT NOT NULL,
        "createdAt" TEXT DEFAULT CURRENT_TIMESTAMP,
        UNIQUE("blockerId", "blockedId")
      );
    `);

    // Virtual Classrooms
    await query(`
      CREATE TABLE IF NOT EXISTS virtual_classes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        "className" TEXT NOT NULL,
        section TEXT,
        specialization TEXT,
        college TEXT,
        "meetingLink" TEXT NOT NULL,
        "scheduledTime" TEXT NOT NULL,
        "teacherId" TEXT NOT NULL,
        "teacherName" TEXT NOT NULL,
        "createdAt" TEXT DEFAULT CURRENT_TIMESTAMP
      );
    `);

    console.log('✅ All tables ready');

    // NOTE: Default seed accounts removed for security.
    // Create test accounts manually or via a separate seed script.

    console.log('✅ PostgreSQL (Neon) Connected & Ready!');
  } catch (err) {
    console.error('❌ DB Init Error:', err);
    process.exit(1);
  }
}

initDB();

// =====================
// HEALTH & STATUS CHECK
// =====================

app.get('/', (req, res) => {
  res.status(200).json({
    status: 'ok',
    message: 'Timetable API Server is live 🚀',
    database: 'PostgreSQL (Neon)',
    endpoints: {
      health: '/health',
      auth: '/api/auth',
      timetable: '/api/timetable',
      lectures: '/api/lectures'
    }
  });
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'Server is running!' });
});

app.get('/api/health', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'Server is running!' });
});

// =====================
// AUTHENTICATION ROUTES
// =====================
// REGISTER
app.post('/api/auth/register', async (req, res) => {
  try {
    const { identifier, name, password, role, className, section, specialization, college, phone } = req.body;

    if (!identifier || !name || !password || !role) {
      return res.status(400).json({
        success: false,
        message: 'Identifier (Email/Username), name, password, and role are required'
      });
    }

    let email = null;
    let username = null;
    if (identifier.includes('@')) {
      email = identifier.trim();
    } else {
      username = identifier.trim();
    }

    let parsedClass = className;
    let parsedSpecialization = specialization;
    if (className && className.includes(' - ')) {
      const parts = className.split(' - ');
      parsedClass = parts[0].trim();
      parsedSpecialization = parts.slice(1).join(' - ').trim();
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const userId = generateId();
    const token = jwt.sign(
      { userId, username, email, role },
      secret,
      { expiresIn: process.env.JWT_EXPIRE || '7d' }
    );

    try {
      await query(
        `INSERT INTO users (id, username, name, email, "passwordHash", role, "className", section, specialization, college, phone) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
        [userId, username, name, email, hashedPassword, role, parsedClass || null, section || null, parsedSpecialization || null, college || null, phone || null]
      );

      res.status(201).json({
        success: true,
        user: { id: userId, username, name, email, role, className: parsedClass, section, specialization: parsedSpecialization, college, phone },
        token
      });
    } catch (err) {
      console.log('Database error:', err);
      if (err.message && err.message.toLowerCase().includes('username')) {
        res.status(400).json({ success: false, message: 'Username already exists' });
      } else if (err.message && err.message.toLowerCase().includes('email')) {
        res.status(400).json({ success: false, message: 'Email already exists' });
      } else {
        res.status(400).json({ success: false, message: 'Registration failed: Identifier already exists' });
      }
    }
  } catch (error) {
    console.log('Error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// LOGIN
app.post('/api/auth/login', async (req, res) => {
  try {
    const { email: identifier, password, role } = req.body;
    console.log(`🔑 Login attempt: Identifier=[${identifier}] Role=[${role}]`);

    const result = await query(
      `SELECT * FROM users WHERE LOWER(email) = LOWER($1) OR LOWER(username) = LOWER($1)`,
      [identifier.trim()]
    );
    const user = result.rows[0];

    if (!user) {
      console.log(`❌ User not found: ${identifier}`);
      return res.status(400).json({ success: false, message: 'User not found' });
    }

    console.log(`✅ User located: ${user.name} (${user.role})`);

    // Strictly enforce role check
    if (role && user.role !== role) {
      console.log(`❌ Role mismatch: Attempted to login as ${role}, but user is ${user.role}`);
      return res.status(400).json({ 
        success: false, 
        message: `Invalid login role. Please login as a ${user.role}.` 
      });
    }

    const passwordMatch = await bcrypt.compare(password, user.passwordHash);
    if (!passwordMatch) {
      return res.status(400).json({ success: false, message: 'Incorrect password' });
    }

    // Check Soft Delete Status
    if (user.deletedAt) {
      const deletedTime = new Date(user.deletedAt);
      const nowTime = new Date();
      const diffTime = Math.abs(nowTime - deletedTime);
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24)); 

      if (diffDays > 30) {
        // More than 30 days, permanently delete
        await query(`DELETE FROM users WHERE id = $1`, [user.id]);
        return res.status(400).json({ success: false, message: 'Your account has been permanently deleted.' });
      } else {
        // Within 30 days, prompt for recovery
        return res.json({ 
          success: false, 
          isSoftDeleted: true, 
          message: `Your account is scheduled for deletion in ${30 - diffDays} days. Would you like to recover it?`,
          daysLeft: 30 - diffDays
        });
      }
    }

    const token = jwt.sign(
      { userId: user.id, email: user.email, role: user.role },
      secret,
      { expiresIn: process.env.JWT_EXPIRE || '7d' }
    );

    res.json({
      success: true,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        className: user.className,
        section: user.section,
        specialization: user.specialization,
        college: user.college,
        phone: user.phone
      },
      token
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});// =====================
// LECTURE ROUTES
// =====================

// DELETE ACCOUNT (SOFT DELETE)
app.delete('/api/users/me', async (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, secret);
    await query(`UPDATE users SET "deletedAt" = $1 WHERE id = $2`, [new Date().toISOString(), decoded.userId]);
    
    res.json({ success: true, message: 'Account scheduled for deletion in 30 days' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// RECOVER ACCOUNT
app.post('/api/users/recover', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    const result = await query(
      `SELECT * FROM users WHERE LOWER(email) = LOWER($1) OR LOWER(username) = LOWER($1)`,
      [email.trim()]
    );
    const user = result.rows[0];

    if (!user) return res.status(400).json({ success: false, message: 'User not found' });

    const passwordMatch = await bcrypt.compare(password, user.passwordHash);
    if (!passwordMatch) return res.status(400).json({ success: false, message: 'Incorrect password' });

    await query(`UPDATE users SET "deletedAt" = NULL WHERE id = $1`, [user.id]);
    
    res.json({ success: true, message: 'Account recovered successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET STUDENT LECTURES
app.get('/api/lectures/student', async (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, secret);
    const studentResult = await query(
      `SELECT "className", section, specialization, college FROM users WHERE id = $1`,
      [decoded.userId]
    );
    const student = studentResult.rows[0];

    if (!student) return res.status(500).json({ success: false, message: 'Student not found' });

    const lectures = await query(
      `SELECT * FROM lectures WHERE UPPER(TRIM("className")) = UPPER(TRIM($1)) AND (section IS NULL OR UPPER(TRIM(section)) = UPPER(TRIM($2))) AND (specialization IS NULL OR UPPER(TRIM(specialization)) = UPPER(TRIM($3))) AND (college IS NULL OR UPPER(TRIM(college)) = UPPER(TRIM($4))) AND "isCancelled" = 0 ORDER BY "startTime"`,
      [student.className, student.section, student.specialization, student.college]
    );

    res.json(lectures.rows);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET TEACHER LECTURES
app.get('/api/lectures/teacher', async (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, secret);
    const lectures = await query(
      `SELECT * FROM lectures WHERE "teacherName" = (SELECT name FROM users WHERE id = $1) ORDER BY "startTime"`,
      [decoded.userId]
    );

    res.json(lectures.rows);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET TIMETABLE FOR SPECIFIC TEACHER
app.get('/api/timetable/teacher', async (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, secret);
    const userResult = await query(`SELECT name FROM users WHERE id = $1`, [decoded.userId]);
    const user = userResult.rows[0];

    if (!user) return res.status(500).json({ success: false, message: 'User not found' });

    const timetable = await query(
      `SELECT * FROM timetable WHERE "teacherName" = $1 ORDER BY "startTime" ASC`,
      [user.name]
    );

    res.json(timetable.rows);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// CREATE LECTURE
app.post('/api/lectures/create', async (req, res) => {
  try {
    const { subjectName, teacherName, className, section, startTime, endTime, roomNumber } = req.body;

    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, secret);
    const teacherResult = await query(`SELECT name, college FROM users WHERE id = $1`, [decoded.userId]);
    const teacher = teacherResult.rows[0];

    if (!teacher) return res.status(500).json({ success: false, message: 'Teacher not found' });

    let parsedClass = className;
    let parsedSpecialization = null;
    if (className && className.includes(' - ')) {
      const parts = className.split(' - ');
      parsedClass = parts[0].trim();
      parsedSpecialization = parts.slice(1).join(' - ').trim();
    }

    const college = teacher.college || null;
    const lectureId = generateId();
    await query(
      `INSERT INTO lectures (id, "subjectName", "teacherName", "className", section, specialization, college, "startTime", "endTime", "roomNumber", "lectureDate") VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
      [lectureId, subjectName, teacherName || teacher.name, parsedClass, section, parsedSpecialization, college, startTime, endTime, roomNumber, new Date().toISOString()]
    );

    res.status(201).json({ success: true, message: 'Lecture created successfully', lectureId });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// CANCEL LECTURE (with ownership check)
app.put('/api/lectures/:lectureId/cancel', async (req, res) => {
  try {
    const { lectureId } = req.params;
    const { cancellationReason } = req.body;

    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, secret);
    const userResult = await query(`SELECT name, role FROM users WHERE id = $1`, [decoded.userId]);
    const user = userResult.rows[0];
    if (!user) return res.status(401).json({ success: false, message: 'User not found' });

    // Only teachers can cancel, and only their own lectures
    if (user.role !== 'teacher') {
      return res.status(403).json({ success: false, message: 'Only teachers can cancel lectures' });
    }

    const lectureResult = await query(`SELECT "teacherName" FROM lectures WHERE id = $1`, [lectureId]);
    const lecture = lectureResult.rows[0];
    if (!lecture) return res.status(404).json({ success: false, message: 'Lecture not found' });
    if (lecture.teacherName !== user.name) {
      return res.status(403).json({ success: false, message: 'You can only cancel your own lectures' });
    }

    await query(
      `UPDATE lectures SET "isCancelled" = 1, "cancellationReason" = $1 WHERE id = $2`,
      [cancellationReason, lectureId]
    );
    await query(`DELETE FROM notifications WHERE "lectureId" = $1`, [lectureId]);

    res.json({ success: true, message: 'Lecture cancelled and related notifications removed' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// =====================
// NOTIFICATION HELPER
// =====================
async function notifyTargetedStudents(className, section, specialization, college, title, message, notificationType, lectureId = null) {
  try {
    let sqlQuery = `SELECT id FROM users WHERE role = 'student' AND UPPER(TRIM("className")) = UPPER(TRIM($1))`;
    let params = [className];

    if (section && section.trim() !== '') {
      sqlQuery += ` AND (UPPER(TRIM(section)) = UPPER(TRIM($2)) OR section IS NULL OR section = '')`;
      params.push(section);
    }

    if (college && college.trim() !== '') {
      sqlQuery += ` AND (UPPER(TRIM(college)) = UPPER(TRIM($${params.length + 1})) OR college IS NULL OR college = '')`;
      params.push(college);
    }

    const students = await query(sqlQuery, params);

    for (const student of students.rows) {
      await query(
        `INSERT INTO notifications (id, "studentId", "lectureId", title, message, "notificationType", "scheduledAt") VALUES ($1,$2,$3,$4,$5,$6,$7)`,
        [generateId(), student.id, lectureId, title, message, notificationType, new Date().toISOString()]
      );
    }
  } catch (error) {
    console.error('Error in notifyTargetedStudents:', error);
  }
}

// =====================
// NOTIFICATION ROUTES
// =====================

// SCHEDULE NOTIFICATION
app.post('/api/notifications/schedule', async (req, res) => {
  try {
    const { lectureId, title, message, notificationType, className, section, scheduledAt } = req.body;

    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, secret);
    const teacherResult = await query(`SELECT college FROM users WHERE id = $1`, [decoded.userId]);
    const teacher = teacherResult.rows[0];
    const college = teacher ? teacher.college : null;

    const students = await query(
      `SELECT id FROM users WHERE role = 'student' AND UPPER(TRIM("className")) = UPPER(TRIM($1)) AND UPPER(TRIM(section)) = UPPER(TRIM($2)) AND (college IS NULL OR UPPER(TRIM(college)) = UPPER(TRIM($3)))`,
      [className, section, college]
    );

    const scheduledTime = scheduledAt || new Date().toISOString();

    // Insert for teacher tracking
    await query(
      `INSERT INTO notifications (id, "studentId", "lectureId", title, message, "notificationType", "scheduledAt") VALUES ($1,$2,$3,$4,$5,$6,$7)`,
      [generateId(), decoded.userId, lectureId, title, message, notificationType, scheduledTime]
    );

    // Insert for all students
    for (const student of students.rows) {
      await query(
        `INSERT INTO notifications (id, "studentId", "lectureId", title, message, "notificationType", "scheduledAt") VALUES ($1,$2,$3,$4,$5,$6,$7)`,
        [generateId(), student.id, lectureId, title, message, notificationType, scheduledTime]
      );
    }

    res.status(201).json({ success: true, message: 'Scheduled successfully.' });
  } catch (error) {
    console.error('❌ Error in schedule route:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// DEBUG endpoint REMOVED for security — was exposing all notifications without auth

// GET ALL NOTIFICATIONS FOR TEACHER
app.get('/api/notifications/teacher', async (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, secret);
    const rows = await query(
      `SELECT n.*, l."subjectName", l."className", l.section 
       FROM notifications n
       LEFT JOIN lectures l ON n."lectureId" = l.id
       WHERE n."studentId" = $1
       ORDER BY n."scheduledAt" DESC`,
      [decoded.userId]
    );

    res.json(rows.rows);
  } catch (error) {
    console.error('❌ Error in getTeacherNotifications:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE NOTIFICATION (with auth check)
app.delete('/api/notifications/:id', async (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, secret);
    const { id } = req.params;

    const rowResult = await query(
      `SELECT "lectureId", "studentId", title, message FROM notifications WHERE id = $1`,
      [id]
    );
    const row = rowResult.rows[0];
    if (!row) return res.status(404).json({ success: false, message: 'Notification not found' });

    // Verify the requesting user owns this notification or is the teacher who sent it
    if (row.studentId !== decoded.userId) {
      return res.status(403).json({ success: false, message: 'You can only delete your own notifications' });
    }

    if (row.lectureId) {
      const result = await query(
        `DELETE FROM notifications WHERE "lectureId" = $1 OR (title = $2 AND message = $3)`,
        [row.lectureId, row.title, row.message]
      );
      res.json({ success: true, message: `Notification cancelled for everyone (${result.rowCount} removed)` });
    } else {
      await query(`DELETE FROM notifications WHERE id = $1`, [id]);
      res.json({ success: true, message: 'Notification deleted' });
    }
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET STUDENT NOTIFICATIONS
app.get('/api/notifications/student', async (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, secret);
    const now = new Date().toISOString();

    const notifications = await query(
      `SELECT * FROM notifications WHERE "studentId" = $1 AND "scheduledAt" <= $2 ORDER BY "scheduledAt" DESC`,
      [decoded.userId, now]
    );

    res.json(notifications.rows);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// MARK NOTIFICATION AS READ
app.put('/api/notifications/:notificationId/read', async (req, res) => {
  try {
    const { notificationId } = req.params;
    await query(`UPDATE notifications SET "isRead" = 1 WHERE id = $1`, [notificationId]);
    res.json({ success: true, message: 'Marked as read' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// =====================
// TIMETABLE ROUTES
// =====================

// CREATE TIMETABLE ENTRY
app.post('/api/timetable/create', async (req, res) => {
  try {
    const { subjectName, teacherName, className, section, day, startTime, endTime, roomNumber } = req.body;

    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, secret);
    const teacherResult = await query(`SELECT name, college FROM users WHERE id = $1`, [decoded.userId]);
    const teacher = teacherResult.rows[0];

    if (!teacher) return res.status(500).json({ success: false, message: 'Teacher not found' });

    let parsedClass = className;
    let parsedSpecialization = null;
    if (className && className.includes(' - ')) {
      const parts = className.split(' - ');
      parsedClass = parts[0].trim();
      parsedSpecialization = parts.slice(1).join(' - ').trim();
    }

    const college = teacher.college || null;
    const timetableId = generateId();
    await query(
      `INSERT INTO timetable (id, "subjectName", "teacherName", "className", section, specialization, college, day, "startTime", "endTime", "roomNumber") VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
      [timetableId, subjectName, teacherName || teacher.name, parsedClass, section, parsedSpecialization, college, day, startTime, endTime, roomNumber]
    );

    // Trigger Notification
    await notifyTargetedStudents(
      parsedClass, section, parsedSpecialization, college,
      'New Timetable Scheduled',
      `Teacher ${teacherName || teacher.name} scheduled ${subjectName} on ${day} at ${startTime}`,
      'timetable',
      timetableId
    );

    res.status(201).json({ success: true, message: 'Timetable entry created successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET TIMETABLE FOR CLASS
app.get('/api/timetable/class/:className', async (req, res) => {
  try {
    const { className } = req.params;
    const token = req.headers.authorization?.split(' ')[1];
    let section = null;
    let specialization = null;
    let college = null;
    let parsedClass = className;

    if (className && className.includes(' - ')) {
      const parts = className.split(' - ');
      parsedClass = parts[0].trim();
      specialization = parts.slice(1).join(' - ').trim();
    }

    if (token) {
      try {
        const decoded = jwt.verify(token, secret);
        const studentResult = await query(
          `SELECT "className", section, specialization, college FROM users WHERE id = $1`,
          [decoded.userId]
        );
        const student = studentResult.rows[0];
        if (student) {
          parsedClass = student.className || parsedClass;
          section = student.section;
          specialization = student.specialization || specialization;
          college = student.college;
        }
      } catch (err) {
        console.log('Token verification failed in timetable endpoint:', err);
      }
    }

    const entries = await query(
      `SELECT * FROM timetable WHERE UPPER(TRIM("className")) = UPPER(TRIM($1)) AND (section IS NULL OR UPPER(TRIM(section)) = UPPER(TRIM($2))) AND (specialization IS NULL OR UPPER(TRIM(specialization)) = UPPER(TRIM($3))) AND (college IS NULL OR UPPER(TRIM(college)) = UPPER(TRIM($4))) ORDER BY day, "startTime"`,
      [parsedClass, section, specialization, college]
    );
    res.json(entries.rows);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET TIMETABLE FOR SPECIFIC DAY
app.get('/api/timetable/day/:className/:day', async (req, res) => {
  try {
    const { className, day } = req.params;
    const entries = await query(
      `SELECT * FROM timetable WHERE UPPER(TRIM("className")) = UPPER(TRIM($1)) AND day = $2 ORDER BY "startTime"`,
      [className, day]
    );
    res.json(entries.rows);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE TIMETABLE ENTRY (with ownership check)
app.delete('/api/timetable/:timetableId', async (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, secret);
    const userResult = await query(`SELECT name, role FROM users WHERE id = $1`, [decoded.userId]);
    const user = userResult.rows[0];
    if (!user) return res.status(401).json({ success: false, message: 'User not found' });

    if (user.role !== 'teacher') {
      return res.status(403).json({ success: false, message: 'Only teachers can delete timetable entries' });
    }

    const { timetableId } = req.params;
    const entry = await query(`SELECT "teacherName" FROM timetable WHERE id = $1`, [timetableId]);
    if (entry.rows.length === 0) return res.status(404).json({ success: false, message: 'Entry not found' });
    if (entry.rows[0].teacherName !== user.name) {
      return res.status(403).json({ success: false, message: 'You can only delete your own timetable entries' });
    }

    await query(`DELETE FROM timetable WHERE id = $1`, [timetableId]);
    res.json({ success: true, message: 'Deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// =====================
// ONLINE TESTS ROUTES
// =====================

// CREATE TEST (Teacher only)
app.post('/api/tests', authenticateToken, async (req, res) => {
  try {
    const user = req.user;
    if (user.role !== 'teacher') return res.status(403).json({ success: false, message: 'Only teachers can create tests' });

    const { title, instructions, className, section, specialization, durationMinutes, questions } = req.body;
    if (!title || !className || !questions || questions.length === 0) {
      return res.status(400).json({ success: false, message: 'Title, className, and at least one question are required' });
    }

    // Fetch teacher name from DB
    const teacherRow = await query(`SELECT name FROM users WHERE id = $1`, [user.userId]);
    const teacherName = teacherRow.rows[0]?.name ?? 'Teacher';

    const testId = generateId();
    await query(
      `INSERT INTO online_tests (id, title, instructions, "className", section, specialization, "durationMinutes", "teacherId", "teacherName") VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
      [testId, title, instructions || '', className, section || null, specialization || null, durationMinutes || 30, user.userId, teacherName]
    );

    for (const q of questions) {
      const qId = generateId();
      await query(
        `INSERT INTO test_questions (id, "testId", "questionText", options, "correctOptionIndex") VALUES ($1,$2,$3,$4,$5)`,
        [qId, testId, q.questionText, JSON.stringify(q.options), q.correctOptionIndex]
      );
    }

    res.status(201).json({ success: true, testId, message: 'Test created successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET TESTS FOR TEACHER
app.get('/api/tests/teacher', authenticateToken, async (req, res) => {
  try {
    const user = req.user;
    if (user.role !== 'teacher') return res.status(403).json({ success: false, message: 'Only teachers can access this' });

    const result = await query(
      `SELECT t.*, COUNT(a.id) as attempt_count FROM online_tests t LEFT JOIN test_attempts a ON t.id = a."testId" WHERE t."teacherId" = $1 GROUP BY t.id ORDER BY t."createdAt" DESC`,
      [user.userId]
    );
    res.json({ success: true, tests: result.rows });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET TESTS FOR A CLASS (Student) — filter by class, section, and optionally specialization
app.get('/api/tests/class/:className/:section', authenticateToken, async (req, res) => {
  try {
    const { className, section } = req.params;
    const { specialization } = req.query;
    const studentId = req.user.userId;

    const result = await query(
      `SELECT t.*, CASE WHEN a.id IS NOT NULL THEN true ELSE false END as attempted, a.score, a."totalQuestions"
       FROM online_tests t
       LEFT JOIN test_attempts a ON t.id = a."testId" AND a."studentId" = $3
       WHERE LOWER(t."className") = LOWER($1)
         AND (t.section IS NULL OR LOWER(t.section) = LOWER($2))
         AND (t.specialization IS NULL OR $4::TEXT IS NULL OR LOWER(t.specialization) = LOWER($4))
       ORDER BY t."createdAt" DESC`,
      [className, section, studentId, specialization || null]
    );
    res.json({ success: true, tests: result.rows });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET QUESTIONS FOR A TEST
app.get('/api/tests/:testId/questions', authenticateToken, async (req, res) => {
  try {
    const { testId } = req.params;
    const testRow = await query(`SELECT * FROM online_tests WHERE id = $1`, [testId]);
    if (testRow.rows.length === 0) return res.status(404).json({ success: false, message: 'Test not found' });

    const questions = await query(`SELECT * FROM test_questions WHERE "testId" = $1`, [testId]);
    // Don't send correct answers to student
    const sanitized = questions.rows.map(q => ({
      id: q.id,
      questionText: q.questionText,
      options: JSON.parse(q.options),
      // Only include correct answer if teacher is requesting
      ...(req.user.role === 'teacher' ? { correctOptionIndex: q.correctOptionIndex } : {})
    }));

    res.json({ success: true, test: testRow.rows[0], questions: sanitized });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET ATTEMPTS FOR A TEST (Teacher only)
app.get('/api/tests/:testId/attempts', authenticateToken, async (req, res) => {
  try {
    const user = req.user;
    if (user.role !== 'teacher') return res.status(403).json({ success: false, message: 'Only teachers can view attempts' });

    const { testId } = req.params;
    const result = await query(
      `SELECT * FROM test_attempts WHERE "testId" = $1 ORDER BY "completedAt" DESC`,
      [testId]
    );
    res.json({ success: true, attempts: result.rows });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// SUBMIT TEST ATTEMPT (Student)
app.post('/api/tests/:testId/attempt', authenticateToken, async (req, res) => {
  try {
    const user = req.user;
    const { testId } = req.params;
    const { answers, studentName } = req.body; // answers: [{ questionId, selectedIndex }]

    // Check if already attempted
    const existing = await query(`SELECT id FROM test_attempts WHERE "testId" = $1 AND "studentId" = $2`, [testId, user.userId]);
    if (existing.rows.length > 0) return res.status(400).json({ success: false, message: 'You have already attempted this test' });

    // Get correct answers
    const questions = await query(`SELECT id, "correctOptionIndex" FROM test_questions WHERE "testId" = $1`, [testId]);
    let score = 0;
    for (const q of questions.rows) {
      const answer = answers.find(a => a.questionId === q.id);
      if (answer && answer.selectedIndex === q.correctOptionIndex) score++;
    }

    const attemptId = generateId();
    await query(
      `INSERT INTO test_attempts (id, "testId", "studentId", "studentName", score, "totalQuestions") VALUES ($1,$2,$3,$4,$5,$6)`,
      [attemptId, testId, user.userId, studentName || 'Student', score, questions.rows.length]
    );

    res.json({ success: true, score, totalQuestions: questions.rows.length, message: 'Test submitted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE TEST (Teacher only)
app.delete('/api/tests/:testId', authenticateToken, async (req, res) => {
  try {
    const user = req.user;
    if (user.role !== 'teacher') return res.status(403).json({ success: false, message: 'Only teachers can delete tests' });

    const { testId } = req.params;
    const test = await query(`SELECT "teacherId" FROM online_tests WHERE id = $1`, [testId]);
    if (test.rows.length === 0) return res.status(404).json({ success: false, message: 'Test not found' });
    if (test.rows[0].teacherId !== user.userId) return res.status(403).json({ success: false, message: 'You can only delete your own tests' });

    await query(`DELETE FROM online_tests WHERE id = $1`, [testId]);
    res.json({ success: true, message: 'Test deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// =====================
// STUDY MATERIALS (NOTES HUB) ROUTES
// =====================

// Multer Storage Configuration
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, path.join(__dirname, 'uploads', 'materials'));
  },
  filename: (req, file, cb) => {
    // Unique filename to avoid collisions
    cb(null, Date.now() + '-' + file.originalname.replace(/\s+/g, '-'));
  }
});
const upload = multer({ storage: storage });

// UPLOAD MATERIAL (Teacher only)
app.post('/api/materials/upload', authenticateToken, upload.single('file'), async (req, res) => {
  try {
    const user = req.user;
    if (user.role !== 'teacher') return res.status(403).json({ success: false, message: 'Only teachers can upload materials' });

    if (!req.file) {
      return res.status(400).json({ success: false, message: 'No file uploaded' });
    }

    const { title, description, className, section, specialization } = req.body;
    
    // Parse class and specialization logic (similar to timetables)
    let parsedClass = className;
    let parsedSpecialization = specialization || null;
    if (className && className.includes(' - ')) {
      const parts = className.split(' - ');
      parsedClass = parts[0].trim();
      parsedSpecialization = parts.slice(1).join(' - ').trim();
    }

    const teacherResult = await query(`SELECT college FROM users WHERE id = $1`, [user.userId]);
    const college = teacherResult.rows[0]?.college || null;

    const fileUrl = '/uploads/materials/' + req.file.filename;
    const materialId = generateId();

    await query(
      `INSERT INTO study_materials (id, title, description, "fileUrl", "fileName", "fileType", "className", section, specialization, college, "teacherId", "teacherName") 
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
      [
        materialId, title, description, fileUrl, req.file.originalname, 
        req.file.mimetype, parsedClass, section, parsedSpecialization, 
        college, user.userId, user.name
      ]
    );

    // Trigger Notification
    await notifyTargetedStudents(
      parsedClass, section, parsedSpecialization, college,
      'New Study Material',
      `Teacher ${user.name} uploaded notes for ${title}`,
      'materials',
      materialId
    );

    res.status(201).json({ success: true, message: 'Material uploaded successfully', materialId, fileUrl });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET MATERIALS FOR STUDENT
app.get('/api/materials/student/:class/:section', authenticateToken, async (req, res) => {
  try {
    const { class: className, section } = req.params;
    const specialization = req.query.specialization;
    
    let parsedClass = className;
    if (className && className.includes(' - ')) {
      parsedClass = className.split(' - ')[0].trim();
    }

    const studentResult = await query(`SELECT college FROM users WHERE id = $1`, [req.user.userId]);
    const college = studentResult.rows[0]?.college || null;

    const result = await query(
      `SELECT * FROM study_materials 
       WHERE "className" = $1 
       AND section = $2 
       AND (specialization IS NULL OR specialization = $3 OR specialization = '')
       AND (college IS NULL OR college = $4)
       ORDER BY "createdAt" DESC`,
      [parsedClass, section, specialization || null, college]
    );

    res.json({ success: true, materials: result.rows });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET MATERIALS UPLOADED BY TEACHER
app.get('/api/materials/teacher', authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== 'teacher') return res.status(403).json({ success: false, message: 'Only teachers can view this' });
    
    const result = await query(
      `SELECT * FROM study_materials WHERE "teacherId" = $1 ORDER BY "createdAt" DESC`,
      [req.user.userId]
    );
    res.json({ success: true, materials: result.rows });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE MATERIAL (Teacher only)
app.delete('/api/materials/:id', authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== 'teacher') return res.status(403).json({ success: false, message: 'Only teachers can delete materials' });
    
    const { id } = req.params;
    
    // Get file info to delete from disk
    const material = await query(`SELECT "fileUrl", "teacherId" FROM study_materials WHERE id = $1`, [id]);
    if (material.rows.length === 0) return res.status(404).json({ success: false, message: 'Material not found' });
    if (material.rows[0].teacherId !== req.user.userId) return res.status(403).json({ success: false, message: 'You can only delete your own materials' });

    // Delete from database
    await query(`DELETE FROM study_materials WHERE id = $1`, [id]);
    
    // Delete file from disk
    const filePath = path.join(__dirname, material.rows[0].fileUrl);
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }

    res.json({ success: true, message: 'Material deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// =====================
// VIRTUAL CLASSROOMS
// =====================

// Create Virtual Class
app.post('/api/virtual_classes', authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== 'teacher') return res.status(403).json({ success: false, message: 'Only teachers can create virtual classes' });
    
    const { title, className, section, specialization, college, meetingLink, scheduledTime } = req.body;
    
    const classId = generateId();
    await query(
      `INSERT INTO virtual_classes (id, title, "className", section, specialization, college, "meetingLink", "scheduledTime", "teacherId", "teacherName")
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
      [classId, title, className, section, specialization, college, meetingLink, scheduledTime, req.user.userId, req.user.name]
    );

    // Trigger Notification to targeted students
    await notifyTargetedStudents(
      className, section, specialization, college,
      'Live Class Scheduled',
      `Teacher ${req.user.name} scheduled a live class: ${title}`,
      'virtual_class',
      classId
    );

    res.json({ success: true, message: 'Virtual Class created successfully', classId });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Get Teacher's Virtual Classes
app.get('/api/virtual_classes/teacher', authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== 'teacher') return res.status(403).json({ success: false, message: 'Only teachers can view this' });
    
    const result = await query(
      `SELECT * FROM virtual_classes WHERE "teacherId" = $1 ORDER BY "createdAt" DESC`,
      [req.user.userId]
    );
    res.json({ success: true, classes: result.rows });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Get Student's Virtual Classes
app.get('/api/virtual_classes/student/:className/:section', authenticateToken, async (req, res) => {
  try {
    const { className, section } = req.params;
    const { specialization } = req.query;

    let sqlQuery = `SELECT * FROM virtual_classes WHERE "className" = $1 AND (section = $2 OR section IS NULL OR section = '')`;
    let params = [className, section];

    if (specialization) {
      sqlQuery += ` AND (specialization = $3 OR specialization IS NULL OR specialization = '')`;
      params.push(specialization);
    }

    sqlQuery += ` ORDER BY "createdAt" DESC`;

    const result = await query(sqlQuery, params);
    res.json({ success: true, classes: result.rows });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Delete Virtual Class
app.delete('/api/virtual_classes/:id', authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== 'teacher') return res.status(403).json({ success: false, message: 'Only teachers can delete' });
    
    const { id } = req.params;
    await query(`DELETE FROM virtual_classes WHERE id = $1 AND "teacherId" = $2`, [id, req.user.userId]);
    res.json({ success: true, message: 'Deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// =====================
// MESSAGING & BLOCKING
// =====================

// Search Users
app.get('/api/messages/search', authenticateToken, async (req, res) => {
  try {
    const { query: searchQuery } = req.query;
    if (!searchQuery) return res.json({ success: true, users: [] });

    const result = await query(
      `SELECT id, name, email, username, role, "className", specialization FROM users 
       WHERE (LOWER(name) LIKE $1 OR LOWER(email) LIKE $1 OR LOWER(username) LIKE $1) 
       AND id != $2 LIMIT 20`,
      [`%${searchQuery.toLowerCase()}%`, req.user.userId]
    );
    res.json({ success: true, users: result.rows });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Get Conversations (Users you have chatted with)
app.get('/api/messages/conversations', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    // Get unique users from messages
    const result = await query(
      `SELECT DISTINCT
         CASE WHEN "senderId" = $1 THEN "receiverId" ELSE "senderId" END as "otherUserId"
       FROM messages 
       WHERE "senderId" = $1 OR "receiverId" = $1`,
      [userId]
    );
    
    if (result.rows.length === 0) return res.json({ success: true, conversations: [] });

    const otherUserIds = result.rows.map(r => r.otherUserId);
    const usersResult = await query(
      `SELECT id, name, username, email, role FROM users WHERE id = ANY($1::text[])`,
      [otherUserIds]
    );

    res.json({ success: true, conversations: usersResult.rows });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Get Chat History with a specific user
app.get('/api/messages/:otherUserId', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { otherUserId } = req.params;

    // Check if blocked by either
    const blockCheck = await query(
      `SELECT * FROM blocked_users WHERE ("blockerId" = $1 AND "blockedId" = $2) OR ("blockerId" = $2 AND "blockedId" = $1)`,
      [userId, otherUserId]
    );

    const isBlocked = blockCheck.rows.length > 0;
    const blockedByMe = blockCheck.rows.some(r => r.blockerId === userId);

    const result = await query(
      `SELECT * FROM messages 
       WHERE ("senderId" = $1 AND "receiverId" = $2) OR ("senderId" = $2 AND "receiverId" = $1)
       ORDER BY "createdAt" ASC`,
      [userId, otherUserId]
    );

    // Mark as read
    await query(
      `UPDATE messages SET "isRead" = 1 WHERE "receiverId" = $1 AND "senderId" = $2 AND "isRead" = 0`,
      [userId, otherUserId]
    );

    res.json({ success: true, messages: result.rows, isBlocked, blockedByMe });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Send Message
app.post('/api/messages/send', authenticateToken, async (req, res) => {
  try {
    const senderId = req.user.userId;
    const { receiverId, content } = req.body;

    // Block check
    const blockCheck = await query(
      `SELECT * FROM blocked_users WHERE ("blockerId" = $1 AND "blockedId" = $2) OR ("blockerId" = $2 AND "blockedId" = $1)`,
      [senderId, receiverId]
    );

    if (blockCheck.rows.length > 0) {
      return res.status(403).json({ success: false, message: 'Cannot send message to this user.' });
    }

    const messageId = generateId();
    await query(
      `INSERT INTO messages (id, "senderId", "receiverId", content) VALUES ($1, $2, $3, $4)`,
      [messageId, senderId, receiverId, content]
    );

    res.json({ success: true, message: 'Sent successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Block User
app.post('/api/users/block', authenticateToken, async (req, res) => {
  try {
    const blockerId = req.user.userId;
    const { blockedId } = req.body;

    await query(
      `INSERT INTO blocked_users (id, "blockerId", "blockedId") VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
      [generateId(), blockerId, blockedId]
    );
    res.json({ success: true, message: 'User blocked' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Unblock User
app.delete('/api/users/block/:blockedId', authenticateToken, async (req, res) => {
  try {
    const blockerId = req.user.userId;
    const { blockedId } = req.params;

    await query(
      `DELETE FROM blocked_users WHERE "blockerId" = $1 AND "blockedId" = $2`,
      [blockerId, blockedId]
    );
    res.json({ success: true, message: 'User unblocked' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// =====================
// START SERVER
// =====================

const PORT = process.env.PORT || 5001;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server running on port ${PORT} (Available to all devices)`);
  console.log('📡 Ready for requests!');
});