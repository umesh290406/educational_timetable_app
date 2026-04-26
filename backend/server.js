const express = require('express');
const { Pool } = require('pg');
const path = require('path');
const dotenv = require('dotenv');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

dotenv.config({ path: path.join(__dirname, '.env') });
const secret = process.env.JWT_SECRET || 'fallback_secret_key_123';
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
  if (req.method === 'POST') console.log('Body:', JSON.stringify(req.body, null, 2));
  next();
});

// =====================
// POSTGRESQL DATABASE SETUP (NEON)
// =====================

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://neondb_owner:npg_A1pxZHKXm2Yf@ep-orange-sunset-an9t43bd.c-6.us-east-1.aws.neon.tech/neondb?sslmode=require',
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

// Setup tables and default accounts
async function initDB() {
  try {
    await query(`
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        "passwordHash" TEXT NOT NULL,
        role TEXT NOT NULL,
        "className" TEXT,
        section TEXT,
        "createdAt" TEXT DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS lectures (
        id TEXT PRIMARY KEY,
        "subjectName" TEXT NOT NULL,
        "teacherName" TEXT NOT NULL,
        "className" TEXT NOT NULL,
        section TEXT,
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
        day TEXT NOT NULL,
        "startTime" TEXT NOT NULL,
        "endTime" TEXT NOT NULL,
        "roomNumber" TEXT,
        "createdAt" TEXT DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('✅ All tables ready');

    // Insert default accounts
    const pass = await bcrypt.hash('password123', 10);
    const teacherPass = await bcrypt.hash('Teacher2904', 10);

    await query(`INSERT INTO users (id, name, email, "passwordHash", role, "className", section) VALUES ($1,$2,$3,$4,$5,$6,$7) ON CONFLICT (email) DO NOTHING`,
      ['test_student_id', 'Test Student', 'student@test.com', pass, 'student', 'SE', 'A']);

    await query(`INSERT INTO users (id, name, email, "passwordHash", role, "className", section) VALUES ($1,$2,$3,$4,$5,$6,$7) ON CONFLICT (email) DO NOTHING`,
      ['test_teacher_id', 'Test Teacher', 'teacher@test.com', pass, 'teacher', 'SE', 'A']);

    await query(`INSERT INTO users (id, name, email, "passwordHash", role, "className", section) VALUES ($1,$2,$3,$4,$5,$6,$7) ON CONFLICT (email) DO NOTHING`,
      ['teacher_id_1', 'Teacher', 'Teacher@gmail.com', teacherPass, 'teacher', 'SE', 'A']);

    console.log('✅ Default accounts ready');

    const users = await query(`SELECT name, email, role FROM users`);
    console.log('--- CURRENT REGISTERED USERS ---');
    console.table(users.rows);

    console.log('✅ PostgreSQL (Neon) Connected & Ready!');
  } catch (err) {
    console.error('❌ DB Init Error:', err);
    process.exit(1);
  }
}

initDB();

// =====================
// HEALTH CHECK
// =====================

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'Server is running!' });
});

// =====================
// AUTHENTICATION ROUTES
// =====================

// REGISTER
app.post('/api/auth/register', async (req, res) => {
  try {
    const { name, email, password, role, className, section } = req.body;

    if (!name || !email || !password || !role) {
      return res.status(400).json({
        success: false,
        message: 'Name, email, password, and role are required'
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const userId = generateId();
    const token = jwt.sign(
      { userId, email, role },
      secret,
      { expiresIn: process.env.JWT_EXPIRE || '7d' }
    );

    try {
      await query(
        `INSERT INTO users (id, name, email, "passwordHash", role, "className", section) VALUES ($1,$2,$3,$4,$5,$6,$7)`,
        [userId, name, email, hashedPassword, role, className || null, section || null]
      );

      res.status(201).json({
        success: true,
        user: { id: userId, name, email, role, className, section },
        token
      });
    } catch (err) {
      console.log('Database error:', err);
      res.status(400).json({ success: false, message: 'Email already exists' });
    }
  } catch (error) {
    console.log('Error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// LOGIN
app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password, role } = req.body;
    console.log(`🔑 Login attempt: Email=[${email}] Role=[${role}]`);

    const result = await query(
      `SELECT * FROM users WHERE LOWER(email) = LOWER($1)`,
      [email.trim()]
    );
    const user = result.rows[0];

    if (!user) {
      console.log(`❌ User not found: ${email}`);
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
        section: user.section
      },
      token
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// =====================
// LECTURE ROUTES
// =====================

// GET STUDENT LECTURES
app.get('/api/lectures/student', async (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, secret);
    const studentResult = await query(
      `SELECT "className", section FROM users WHERE id = $1`,
      [decoded.userId]
    );
    const student = studentResult.rows[0];

    if (!student) return res.status(500).json({ success: false, message: 'Student not found' });

    const lectures = await query(
      `SELECT * FROM lectures WHERE UPPER(TRIM("className")) = UPPER(TRIM($1)) AND "isCancelled" = 0 ORDER BY "startTime"`,
      [student.className]
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
    const teacherResult = await query(`SELECT name FROM users WHERE id = $1`, [decoded.userId]);
    const teacher = teacherResult.rows[0];

    if (!teacher) return res.status(500).json({ success: false, message: 'Teacher not found' });

    const lectureId = generateId();
    await query(
      `INSERT INTO lectures (id, "subjectName", "teacherName", "className", section, "startTime", "endTime", "roomNumber", "lectureDate") VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
      [lectureId, subjectName, teacherName || teacher.name, className, section, startTime, endTime, roomNumber, new Date().toISOString()]
    );

    res.status(201).json({ success: true, message: 'Lecture created successfully', lectureId });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// CANCEL LECTURE
app.put('/api/lectures/:lectureId/cancel', async (req, res) => {
  try {
    const { lectureId } = req.params;
    const { cancellationReason } = req.body;

    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

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
// NOTIFICATION ROUTES
// =====================

// SCHEDULE NOTIFICATION
app.post('/api/notifications/schedule', async (req, res) => {
  try {
    const { lectureId, title, message, notificationType, className, section, scheduledAt } = req.body;

    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, secret);
    const teacherId = decoded.userId;

    const students = await query(
      `SELECT id FROM users WHERE role = 'student' AND UPPER(TRIM("className")) = UPPER(TRIM($1)) AND UPPER(TRIM(section)) = UPPER(TRIM($2))`,
      [className, section]
    );

    const scheduledTime = scheduledAt || new Date().toISOString();

    // Insert for teacher tracking
    await query(
      `INSERT INTO notifications (id, "studentId", "lectureId", title, message, "notificationType", "scheduledAt") VALUES ($1,$2,$3,$4,$5,$6,$7)`,
      [generateId(), teacherId, lectureId, title, message, notificationType, scheduledTime]
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

// DEBUG: GET ALL NOTIFICATIONS (also used by UptimeRobot ping)
app.get('/api/debug/notifications', async (req, res) => {
  try {
    const rows = await query(`SELECT * FROM notifications`);
    res.json(rows.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

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

// DELETE NOTIFICATION
app.delete('/api/notifications/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const rowResult = await query(
      `SELECT "lectureId", title, message FROM notifications WHERE id = $1`,
      [id]
    );
    const row = rowResult.rows[0];
    if (!row) return res.status(404).json({ success: false, message: 'Notification not found' });

    if (row.lectureId) {
      const result = await query(
        `DELETE FROM notifications WHERE "lectureId" = $1 OR (title = $2 AND message = $3)`,
        [row.lectureId, row.title, row.message]
      );
      console.log(`[SYNC] Removed ${result.rowCount} notifications across all dashboards.`);
      res.json({ success: true, message: `Notification cancelled for everyone (${result.rowCount} removed)` });
    } else {
      await query(`DELETE FROM notifications WHERE id = $1`, [id]);
      res.json({ success: true, message: 'Notification deleted' });
    }
  } catch (error) {
    console.error('❌ Error in notification delete route:', error);
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
    const userResult = await query(`SELECT name FROM users WHERE id = $1`, [decoded.userId]);
    const user = userResult.rows[0];

    if (!user) return res.status(500).json({ success: false, message: 'User not found' });

    const timetableId = generateId();
    await query(
      `INSERT INTO timetable (id, "subjectName", "teacherName", "className", section, day, "startTime", "endTime", "roomNumber") VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
      [timetableId, subjectName, teacherName || user.name, className, section, day, startTime, endTime, roomNumber]
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
    const entries = await query(
      `SELECT * FROM timetable WHERE UPPER(TRIM("className")) = UPPER(TRIM($1)) ORDER BY day, "startTime"`,
      [className]
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

// DELETE TIMETABLE ENTRY
app.delete('/api/timetable/:timetableId', async (req, res) => {
  try {
    const { timetableId } = req.params;
    await query(`DELETE FROM timetable WHERE id = $1`, [timetableId]);
    res.json({ success: true, message: 'Deleted successfully' });
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