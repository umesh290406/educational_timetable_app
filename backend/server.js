const express = require('express');
const Database = require('better-sqlite3');
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
// SQLITE DATABASE SETUP
// =====================

const dbPath = path.join(__dirname, 'timetable.db');
let db;
try {
  db = new Database(dbPath);
  console.log('✅ SQLite Connected');
  console.log(`📁 Database file: ${dbPath}`);
} catch (err) {
  console.log('❌ SQLite Error:', err);
  process.exit(1);
}

// Enable foreign keys
db.pragma('foreign_keys = ON');

// Create Tables
db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    passwordHash TEXT NOT NULL,
    role TEXT NOT NULL,
    className TEXT,
    section TEXT,
    createdAt TEXT DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS lectures (
    id TEXT PRIMARY KEY,
    subjectName TEXT NOT NULL,
    teacherName TEXT NOT NULL,
    className TEXT NOT NULL,
    section TEXT,
    startTime TEXT NOT NULL,
    endTime TEXT NOT NULL,
    roomNumber TEXT,
    lectureDate TEXT NOT NULL,
    isCancelled INTEGER DEFAULT 0,
    cancellationReason TEXT,
    createdAt TEXT DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS notifications (
    id TEXT PRIMARY KEY,
    studentId TEXT NOT NULL,
    lectureId TEXT,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    notificationType TEXT,
    isRead INTEGER DEFAULT 0,
    scheduledAt TEXT DEFAULT CURRENT_TIMESTAMP,
    createdAt TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (studentId) REFERENCES users(id)
  );

  CREATE TABLE IF NOT EXISTS timetable (
    id TEXT PRIMARY KEY,
    subjectName TEXT NOT NULL,
    teacherName TEXT NOT NULL,
    className TEXT NOT NULL,
    section TEXT,
    day TEXT NOT NULL,
    startTime TEXT NOT NULL,
    endTime TEXT NOT NULL,
    roomNumber TEXT,
    createdAt TEXT DEFAULT CURRENT_TIMESTAMP
  );
`);
console.log('✅ All tables ready');

// Create default test accounts
const pass = bcrypt.hashSync('password123', 10);

const insertUser = db.prepare(`INSERT OR IGNORE INTO users (id, name, email, passwordHash, role, className, section) VALUES (?, ?, ?, ?, ?, ?, ?)`);

insertUser.run('test_student_id', 'Test Student', 'student@test.com', pass, 'student', 'SE', 'A');
insertUser.run('test_teacher_id', 'Test Teacher', 'teacher@test.com', pass, 'teacher', 'SE', 'A');

const teacherPass = bcrypt.hashSync('Teacher2904', 10);
insertUser.run('teacher_id_1', 'Teacher', 'Teacher@gmail.com', teacherPass, 'teacher', 'SE', 'A');

console.log('✅ Default accounts ready');

const users = db.prepare('SELECT name, email, role FROM users').all();
console.log('--- CURRENT REGISTERED USERS ---');
console.table(users);

// Make db globally accessible
global.db = db;

// =====================
// HELPER FUNCTIONS
// =====================

function generateId() {
  return 'id_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
}

// Health check route
app.get('/api/health', (req, res) => {
  res.status(200).send('OK');
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
      db.prepare(
        `INSERT INTO users (id, name, email, passwordHash, role, className, section) VALUES (?, ?, ?, ?, ?, ?, ?)`
      ).run(userId, name, email, hashedPassword, role, className || null, section || null);

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
    console.log(`🔑 Login attempt: Email=[${email}] Password=[${password}] Role=[${role}]`);

    const user = db.prepare(`SELECT * FROM users WHERE LOWER(email) = LOWER(?)`).get(email.trim());

    if (!user) {
      console.log(`❌ User not found: ${email}`);
      return res.status(400).json({ success: false, message: 'User not found' });
    }

    console.log(`✅ User located: ${user.name} (${user.role})`);

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
app.get('/api/lectures/student', (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, secret);
    const student = db.prepare(`SELECT className, section FROM users WHERE id = ?`).get(decoded.userId);

    if (!student) return res.status(500).json({ success: false, message: 'Student not found' });

    const lectures = db.prepare(
      `SELECT * FROM lectures WHERE UPPER(TRIM(className)) = UPPER(TRIM(?)) AND isCancelled = 0 ORDER BY startTime`
    ).all(student.className);

    res.json(lectures);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET TEACHER LECTURES
app.get('/api/lectures/teacher', (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, secret);
    const lectures = db.prepare(
      `SELECT * FROM lectures WHERE teacherName = (SELECT name FROM users WHERE id = ?) ORDER BY startTime`
    ).all(decoded.userId);

    res.json(lectures);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET TIMETABLE FOR SPECIFIC TEACHER
app.get('/api/timetable/teacher', (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, secret);
    const user = db.prepare(`SELECT name FROM users WHERE id = ?`).get(decoded.userId);

    if (!user) return res.status(500).json({ success: false, message: 'User not found' });

    const timetable = db.prepare(
      `SELECT * FROM timetable WHERE teacherName = ? ORDER BY startTime ASC`
    ).all(user.name);

    res.json(timetable);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// CREATE LECTURE
app.post('/api/lectures/create', (req, res) => {
  try {
    const { subjectName, teacherName, className, section, startTime, endTime, roomNumber } = req.body;

    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, secret);
    const teacher = db.prepare(`SELECT name FROM users WHERE id = ?`).get(decoded.userId);

    if (!teacher) return res.status(500).json({ success: false, message: 'Teacher not found' });

    const lectureId = generateId();
    db.prepare(
      `INSERT INTO lectures (id, subjectName, teacherName, className, section, startTime, endTime, roomNumber, lectureDate) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(lectureId, subjectName, teacherName || teacher.name, className, section, startTime, endTime, roomNumber, new Date().toISOString());

    res.status(201).json({ success: true, message: 'Lecture created successfully', lectureId });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// CANCEL LECTURE
app.put('/api/lectures/:lectureId/cancel', (req, res) => {
  try {
    const { lectureId } = req.params;
    const { cancellationReason } = req.body;

    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    db.prepare(`UPDATE lectures SET isCancelled = 1, cancellationReason = ? WHERE id = ?`).run(cancellationReason, lectureId);
    db.prepare(`DELETE FROM notifications WHERE lectureId = ?`).run(lectureId);

    res.json({ success: true, message: 'Lecture cancelled and related notifications removed' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// =====================
// NOTIFICATION ROUTES
// =====================

// SCHEDULE NOTIFICATION
app.post('/api/notifications/schedule', (req, res) => {
  try {
    const { lectureId, title, message, notificationType, className, section, scheduledAt } = req.body;

    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, secret);
    const teacherId = decoded.userId;

    const students = db.prepare(
      `SELECT id FROM users WHERE role = 'student' AND UPPER(TRIM(className)) = UPPER(TRIM(?)) AND UPPER(TRIM(section)) = UPPER(TRIM(?))`
    ).all(className, section);

    const insert = db.prepare(
      `INSERT INTO notifications (id, studentId, lectureId, title, message, notificationType, scheduledAt) VALUES (?, ?, ?, ?, ?, ?, ?)`
    );

    const scheduledTime = scheduledAt || new Date().toISOString();

    // Insert for teacher tracking
    insert.run(generateId(), teacherId, lectureId, title, message, notificationType, scheduledTime);

    // Insert for all students
    if (students && students.length > 0) {
      students.forEach(student => {
        insert.run(generateId(), student.id, lectureId, title, message, notificationType, scheduledTime);
      });
    }

    res.status(201).json({ success: true, message: 'Scheduled successfully.' });
  } catch (error) {
    console.error('❌ Error in schedule route:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// DEBUG: GET ALL NOTIFICATIONS
app.get('/api/debug/notifications', (req, res) => {
  try {
    const rows = db.prepare(`SELECT * FROM notifications`).all();
    res.json(rows);
  } catch (err) {
    res.status(500).json(err);
  }
});

// GET ALL NOTIFICATIONS FOR TEACHER
app.get('/api/notifications/teacher', (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, secret);
    const rows = db.prepare(
      `SELECT n.*, l.subjectName, l.className, l.section 
       FROM notifications n
       LEFT JOIN lectures l ON n.lectureId = l.id
       WHERE n.studentId = ?
       ORDER BY n.scheduledAt DESC`
    ).all(decoded.userId);

    res.json(rows);
  } catch (error) {
    console.error('❌ Error in getTeacherNotifications:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE NOTIFICATION
app.delete('/api/notifications/:id', (req, res) => {
  try {
    const { id } = req.params;

    const row = db.prepare(`SELECT lectureId, title, message FROM notifications WHERE id = ?`).get(id);
    if (!row) return res.status(404).json({ success: false, message: 'Notification not found' });

    if (row.lectureId) {
      const result = db.prepare(
        `DELETE FROM notifications WHERE lectureId = ? OR (title = ? AND message = ?)`
      ).run(row.lectureId, row.title, row.message);
      console.log(`[SYNC] Removed ${result.changes} notifications across all dashboards.`);
      res.json({ success: true, message: `Notification cancelled for everyone (${result.changes} removed)` });
    } else {
      db.prepare(`DELETE FROM notifications WHERE id = ?`).run(id);
      res.json({ success: true, message: 'Notification deleted' });
    }
  } catch (error) {
    console.error('❌ Error in notification delete route:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET STUDENT NOTIFICATIONS
app.get('/api/notifications/student', (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, secret);
    const now = new Date().toISOString();

    const notifications = db.prepare(
      `SELECT * FROM notifications WHERE studentId = ? AND scheduledAt <= ? ORDER BY scheduledAt DESC`
    ).all(decoded.userId, now);

    res.json(notifications);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// MARK NOTIFICATION AS READ
app.put('/api/notifications/:notificationId/read', (req, res) => {
  try {
    const { notificationId } = req.params;
    db.prepare(`UPDATE notifications SET isRead = 1 WHERE id = ?`).run(notificationId);
    res.json({ success: true, message: 'Marked as read' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// =====================
// TIMETABLE ROUTES
// =====================

// CREATE TIMETABLE ENTRY
app.post('/api/timetable/create', (req, res) => {
  try {
    const { subjectName, teacherName, className, section, day, startTime, endTime, roomNumber } = req.body;

    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const decoded = jwt.verify(token, secret);
    const user = db.prepare(`SELECT name FROM users WHERE id = ?`).get(decoded.userId);

    if (!user) return res.status(500).json({ success: false, message: 'User not found' });

    const timetableId = generateId();
    db.prepare(
      `INSERT INTO timetable (id, subjectName, teacherName, className, section, day, startTime, endTime, roomNumber) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(timetableId, subjectName, teacherName || user.name, className, section, day, startTime, endTime, roomNumber);

    res.status(201).json({ success: true, message: 'Timetable entry created successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET TIMETABLE FOR CLASS
app.get('/api/timetable/class/:className', (req, res) => {
  try {
    const { className } = req.params;
    const entries = db.prepare(
      `SELECT * FROM timetable WHERE UPPER(TRIM(className)) = UPPER(TRIM(?)) ORDER BY day, startTime`
    ).all(className);
    res.json(entries);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET TIMETABLE FOR SPECIFIC DAY
app.get('/api/timetable/day/:className/:day', (req, res) => {
  try {
    const { className, day } = req.params;
    const entries = db.prepare(
      `SELECT * FROM timetable WHERE UPPER(TRIM(className)) = UPPER(TRIM(?)) AND day = ? ORDER BY startTime`
    ).all(className, day);
    res.json(entries);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE TIMETABLE ENTRY
app.delete('/api/timetable/:timetableId', (req, res) => {
  try {
    const { timetableId } = req.params;
    db.prepare(`DELETE FROM timetable WHERE id = ?`).run(timetableId);
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