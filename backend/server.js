const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const dotenv = require('dotenv');
const cors = require('cors');

dotenv.config({ path: path.join(__dirname, '.env') });
const secret = process.env.JWT_SECRET || 'fallback_secret_key_123';
const app = express();

// Middleware
app.use(cors({
  origin: function(origin, callback) {
    // Allow requests with no origin (mobile apps, curl, etc.)
    if (!origin) return callback(null, true);
    // Allow all localhost origins (any port) for Flutter web dev
    if (origin.match(/^http:\/\/localhost(:\d+)?$/) ||
        origin.match(/^http:\/\/127\.0\.0\.1(:\d+)?$/)) {
      return callback(null, true);
    }
    // Allow all for local testing
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
const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.log('❌ SQLite Error:', err);
  } else {
    console.log('✅ SQLite Connected');
    console.log(`📁 Database file: ${dbPath}`);
  }
});

// Enable foreign keys
db.run('PRAGMA foreign_keys = ON');

// Create Tables Sequence
db.serialize(() => {
  // Create Users Table
  db.run(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL,
      passwordHash TEXT NOT NULL,
      role TEXT NOT NULL,
      className TEXT,
      section TEXT,
      createdAt TEXT DEFAULT CURRENT_TIMESTAMP
    )
  `, (err) => {
    if (err) console.error('❌ Error creating users table:', err);
    else console.log('✅ Users table ready');
  });

  // Create Lectures Table
  db.run(`
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
    )
  `);

  // Create Notifications Table
  db.run(`
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
    )
  `);

  // Create Timetable Table
  db.run(`
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
    )
  `);

  // Create test accounts inside the SAME serialize block
  const bcrypt = require('bcryptjs');
  const pass = bcrypt.hashSync('password123', 10);

  db.get(`SELECT id FROM users WHERE email = 'student@test.com'`, (err, student) => {
    if (!student) {
      db.run(`INSERT INTO users (id, name, email, passwordHash, role, className, section) 
              VALUES (?, ?, ?, ?, ?, ?, ?)`, 
              ['test_student_id', 'Test Student', 'student@test.com', pass, 'student', 'SE', 'A']);
      console.log('✅ Created test student: student@test.com / password123');
    }
  });

  db.get(`SELECT id FROM users WHERE email = 'teacher@test.com'`, (err, teacher) => {
    if (!teacher) {
      db.run(`INSERT INTO users (id, name, email, passwordHash, role, className, section) 
              VALUES (?, ?, ?, ?, ?, ?, ?)`, 
              ['test_teacher_id', 'Test Teacher', 'teacher@test.com', pass, 'teacher', 'SE', 'A']);
      console.log('✅ Created test teacher: teacher@test.com / password123');
    }
  });

  // ENSURE THE DEFAULT TEACHER ACCOUNT EXISTS
  db.get(`SELECT id FROM users WHERE email = 'Teacher@gmail.com'`, (err, user) => {
    if (!user) {
      const teacherPass = bcrypt.hashSync('Teacher2904', 10);
      db.run(`INSERT INTO users (id, name, email, passwordHash, role, className, section) 
              VALUES (?, ?, ?, ?, ?, ?, ?)`, 
              ['teacher_id_1', 'Teacher', 'Teacher@gmail.com', teacherPass, 'teacher', 'SE', 'A']);
      console.log('✅ Created teacher account: Teacher@gmail.com / Teacher2904');
    }
  });

  // LIST ALL USERS FOR DEBUGGING
  db.all('SELECT name, email, role FROM users', (err, users) => {
    console.log('--- CURRENT REGISTERED USERS ---');
    console.table(users);
  });
});

// Make db globally accessible
global.db = db;

// =====================
// HELPER FUNCTIONS
// =====================

// Generate unique ID
function generateId() {
  return 'id_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
}

// =====================
// AUTHENTICATION ROUTES
// =====================

// REGISTER
app.post('/api/auth/register', async (req, res) => {
  try {
    const { name, email, password, role, className, section } = req.body;

    // Validation
    if (!name || !email || !password || !role) {
      return res.status(400).json({
        success: false,
        message: 'Name, email, password, and role are required'
      });
    }

    // Hash password
    const bcrypt = require('bcryptjs');
    const hashedPassword = await bcrypt.hash(password, 10);

    // Generate token
    const jwt = require('jsonwebtoken');
    const userId = generateId();
    const token = jwt.sign(
      { userId, email, role },
      secret,
      { expiresIn: process.env.JWT_EXPIRE || '7d' }
    );

    // Insert into database
    db.run(
      `INSERT INTO users (id, name, email, passwordHash, role, className, section) 
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [userId, name, email, hashedPassword, role, className || null, section || null],
      (err) => {
        if (err) {
          console.log('Database error:', err);
          return res.status(400).json({
            success: false,
            message: 'Email already exists'
          });
        }

        res.status(201).json({
          success: true,
          user: {
            id: userId,
            name: name,
            email: email,
            role: role,
            className: className,
            section: section
          },
          token: token
        });
      }
    );
  } catch (error) {
    console.log('Error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// LOGIN
app.post('/api/auth/login', (req, res) => {
  try {
    const { email, password, role } = req.body;
    console.log(`🔑 Login attempt: Email=[${email}] Password=[${password}] Role=[${role}]`);

  // Find user
    db.get(
      `SELECT * FROM users WHERE LOWER(email) = LOWER(?)`,
      [email.trim()],
      async (err, user) => {
        if (err) {
          console.error('❌ Database error during login:', err);
          return res.status(500).json({
            success: false,
            message: 'Database error'
          });
        }

        if (!user) {
          console.log(`❌ User not found: ${email}`);
          return res.status(400).json({
            success: false,
            message: 'User not found'
          });
        }

        console.log(`✅ User located: ${user.name} (${user.role})`);

        // Verify password
        const bcrypt = require('bcryptjs');
        const passwordMatch = await bcrypt.compare(password, user.passwordHash);

        if (!passwordMatch) {
          return res.status(400).json({
            success: false,
            message: 'Incorrect password'
          });
        }

        // Generate token
        const jwt = require('jsonwebtoken');
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
          token: token
        });
      }
    );
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// =====================
// LECTURE ROUTES
// =====================

// GET STUDENT LECTURES
app.get('/api/lectures/student', (req, res) => {
  try {
    // Get token from header
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) {
      return res.status(401).json({ success: false, message: 'No token' });
    }

    // Verify token
    const jwt = require('jsonwebtoken');
    const decoded = jwt.verify(token, secret);
    
    // Get student's class
    db.get(
      `SELECT className, section FROM users WHERE id = ?`,
      [decoded.userId],
      (err, student) => {
        if (err || !student) {
          return res.status(500).json({ success: false, message: 'Student not found' });
        }

        // Get lectures for student's class
        db.all(
          `SELECT * FROM lectures WHERE UPPER(TRIM(className)) = UPPER(TRIM(?)) AND isCancelled = 0 ORDER BY startTime`,
          [student.className],
          (err, lectures) => {
            if (err) {
              return res.status(500).json({ success: false, message: 'Database error' });
            }

            res.json(lectures);
          }
        );
      }
    );
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// GET TEACHER LECTURES
app.get('/api/lectures/teacher', (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) {
      return res.status(401).json({ success: false, message: 'No token' });
    }

    const jwt = require('jsonwebtoken');
    const decoded = jwt.verify(token, secret);

    // Get all lectures for this teacher
    db.all(
      `SELECT * FROM lectures WHERE teacherName = (SELECT name FROM users WHERE id = ?) ORDER BY startTime`,
      [decoded.userId],
      (err, lectures) => {
        if (err) {
          return res.status(500).json({ success: false, message: 'Database error' });
        }

        res.json(lectures);
      }
    );
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// GET TIMETABLE FOR SPECIFIC TEACHER
app.get('/api/timetable/teacher', (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const jwt = require('jsonwebtoken');
    const decoded = jwt.verify(token, secret);

    // Find teacher name first
    db.get(`SELECT name FROM users WHERE id = ?`, [decoded.userId], (err, user) => {
      if (err || !user) return res.status(500).json({ success: false, message: 'User not found' });

      db.all(
        `SELECT * FROM timetable WHERE teacherName = ? ORDER BY startTime ASC`,
        [user.name],
        (err, timetable) => {
          if (err) return res.status(500).json({ success: false, message: 'Database error' });
          res.json(timetable);
        }
      );
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// CREATE LECTURE
app.post('/api/lectures/create', (req, res) => {
  try {
    const { subjectName, teacherName, className, section, startTime, endTime, roomNumber } = req.body;

    const token = req.headers.authorization?.split(' ')[1];
    if (!token) {
      return res.status(401).json({ success: false, message: 'No token' });
    }

    const jwt = require('jsonwebtoken');
    const decoded = jwt.verify(token, secret);

    // Get teacher name
    db.get(
      `SELECT name FROM users WHERE id = ?`,
      [decoded.userId],
      (err, teacher) => {
        if (err || !teacher) {
          return res.status(500).json({ success: false, message: 'Teacher not found' });
        }

        const lectureId = generateId();

        db.run(
          `INSERT INTO lectures (id, subjectName, teacherName, className, section, startTime, endTime, roomNumber, lectureDate) 
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [lectureId, subjectName, teacherName || teacher.name, className, section, startTime, endTime, roomNumber, new Date().toISOString()],
          (err) => {
            if (err) {
              return res.status(400).json({
                success: false,
                message: 'Failed to create lecture'
              });
            }

            res.status(201).json({
              success: true,
              message: 'Lecture created successfully',
              lectureId: lectureId
            });
          }
        );
      }
    );
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// CANCEL LECTURE
app.put('/api/lectures/:lectureId/cancel', (req, res) => {
  try {
    const { lectureId } = req.params;
    const { cancellationReason } = req.body;

    const token = req.headers.authorization?.split(' ')[1];
    if (!token) {
      return res.status(401).json({ success: false, message: 'No token' });
    }

    db.run(
      `UPDATE lectures SET isCancelled = 1, cancellationReason = ? WHERE id = ?`,
      [cancellationReason, lectureId],
      (err) => {
        if (err) {
          return res.status(500).json({ success: false, message: 'Database error' });
        }

        // Also delete any scheduled notifications for this lecture
        db.run(
          `DELETE FROM notifications WHERE lectureId = ?`,
          [lectureId],
          (errorNotif) => {
            if (errorNotif) {
              console.error('❌ Error deleting related notifications on cancel:', errorNotif);
            }
            res.json({
              success: true,
              message: 'Lecture cancelled and related notifications removed'
            });
          }
        );
      }
    );
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// =====================
// NOTIFICATION ROUTES
// =====================

// SCHEDULE NOTIFICATION FOR CLASS
app.post('/api/notifications/schedule', (req, res) => {
  try {
    const { lectureId, title, message, notificationType, className, section, scheduledAt } = req.body;
    
    // Get teacher ID from token
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });
    
    const jwt = require('jsonwebtoken');
    const decoded = jwt.verify(token, secret);
    const teacherId = decoded.userId;

    // Find students in this class
    db.all(
      `SELECT id FROM users WHERE role = 'student' AND UPPER(TRIM(className)) = UPPER(TRIM(?)) AND UPPER(TRIM(section)) = UPPER(TRIM(?))`,
      [className, section],
      (err, students) => {
        if (err) {
          console.error('❌ Database error during student lookup:', err);
          return res.status(500).json({ success: false, message: 'Database error' });
        }

        const stmt = db.prepare(`
          INSERT INTO notifications (id, studentId, lectureId, title, message, notificationType, scheduledAt)
          VALUES (?, ?, ?, ?, ?, ?, ?)
        `);

        // 1. Always insert ONE record for the teacher (for their dashboard tracking)
        // This ensures the reminder is "saved" even if students are 0
        stmt.run([generateId(), teacherId, lectureId, title, message, notificationType, scheduledAt || new Date().toISOString()], (err) => {
           if (err) console.error('❌ Error inserting teacher reference:', err);
        });

        // 2. Insert for all students
        if (students && students.length > 0) {
          students.forEach(student => {
            stmt.run([generateId(), student.id, lectureId, title, message, notificationType, scheduledAt || new Date().toISOString()], (err) => {
              if (err) console.error('❌ Error inserting student notification:', err);
            });
          });
        }

        stmt.finalize();
        res.status(201).json({ success: true, message: `Scheduled successfully.` });
      }
    );
  } catch (error) {
    console.error('❌ Error in schedule route:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET UNREAD STUDENT NOTIFICATIONS (Scheduled for now or past)
// DEBUG: GET ALL NOTIFICATIONS
app.get('/api/debug/notifications', (req, res) => {
  db.all(`SELECT * FROM notifications`, (err, rows) => {
    if (err) return res.status(500).json(err);
    res.json(rows);
  });
});

// GET ALL NOTIFICATIONS FOR A TEACHER
app.get('/api/notifications/teacher', (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const jwt = require('jsonwebtoken');
    const decoded = jwt.verify(token, secret);

    // Return only the notifications created for the teacher's own tracking
    // Simplified query to avoid join issues while debugging
    db.all(
      `SELECT n.*, l.subjectName, l.className, l.section 
       FROM notifications n
       LEFT JOIN lectures l ON n.lectureId = l.id
       WHERE n.studentId = ?
       ORDER BY n.scheduledAt DESC`,
      [decoded.userId],
      (err, rows) => {
        if (err) {
          console.error('❌ Database error fetching teacher notifications:', err);
          return res.status(500).json({ success: false, message: 'Database error' });
        }
        res.json(rows);
      }
    );
  } catch (error) {
    console.error('❌ Error in getTeacherNotifications:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE NOTIFICATION (CANCEL REMINDER GLOBALLY)
app.delete('/api/notifications/:id', (req, res) => {
  try {
    const { id } = req.params;
    
    // First, find the details of the notification being deleted
    db.get(`SELECT lectureId, title, message FROM notifications WHERE id = ?`, [id], (err, row) => {
      if (err || !row) {
        return res.status(404).json({ success: false, message: 'Notification not found' });
      }

      // If it's linked to a lecture, delete for ALL students and the teacher
      if (row.lectureId) {
        console.log(`[SYNC] Deleting all notifications for lectureId: ${row.lectureId} or matching title: "${row.title}"`);
        db.run(
          `DELETE FROM notifications 
           WHERE lectureId = ? OR (title = ? AND message = ?)`,
          [row.lectureId, row.title, row.message],
          function(err) {
            if (err) {
              console.error('❌ Error in global notification delete:', err);
              return res.status(500).json({ success: false, message: 'Database error' });
            }
            console.log(`[SYNC] Removed ${this.changes} notifications across all dashboards.`);
            res.json({ success: true, message: `Notification cancelled for everyone (${this.changes} removed)` });
          }
        );
      } else {
        // Fallback for standalone notifications
        db.run(`DELETE FROM notifications WHERE id = ?`, [id], (err) => {
          if (err) return res.status(500).json({ success: false, message: 'Database error' });
          res.json({ success: true, message: 'Notification deleted' });
        });
      }
    });
  } catch (error) {
    console.error('❌ Error in notification delete route:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/notifications/student', (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ success: false, message: 'No token' });

    const jwt = require('jsonwebtoken');
    const decoded = jwt.verify(token, secret);

    const now = new Date().toISOString();
    db.all(
      `SELECT * FROM notifications 
       WHERE studentId = ? AND scheduledAt <= ? 
       ORDER BY scheduledAt DESC`,
      [decoded.userId, now],
      (err, notifications) => {
        if (err) return res.status(500).json({ success: false, message: 'Database error' });
        res.json(notifications);
      }
    );
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// MARK NOTIFICATION AS READ
app.put('/api/notifications/:notificationId/read', (req, res) => {
  try {
    const { notificationId } = req.params;
    db.run(
      `UPDATE notifications SET isRead = 1 WHERE id = ?`,
      [notificationId],
      (err) => {
        if (err) return res.status(500).json({ success: false, message: 'Database error' });
        res.json({ success: true, message: 'Marked as read' });
      }
    );
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// CREATE TIMETABLE ENTRY
app.post('/api/timetable/create', (req, res) => {
  try {
    const { subjectName, teacherName, className, section, day, startTime, endTime, roomNumber } = req.body;
    
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) {
      return res.status(401).json({ success: false, message: 'No token' });
    }

    const jwt = require('jsonwebtoken');
    const decoded = jwt.verify(token, secret);

    db.get(
      `SELECT name FROM users WHERE id = ?`,
      [decoded.userId],
      (err, user) => {
        if (err || !user) {
          return res.status(500).json({ success: false, message: 'User not found' });
        }

        const timetableId = generateId();

        db.run(
          `INSERT INTO timetable (id, subjectName, teacherName, className, section, day, startTime, endTime, roomNumber) 
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [timetableId, subjectName, teacherName || user.name, className, section, day, startTime, endTime, roomNumber],
          (err) => {
            if (err) {
              return res.status(400).json({
                success: false,
                message: 'Failed to create timetable entry'
              });
            }

            res.status(201).json({
              success: true,
              message: 'Timetable entry created successfully'
            });
          }
        );
      }
    );
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET TIMETABLE FOR CLASS
app.get('/api/timetable/class/:className', (req, res) => {
  try {
    const { className } = req.params;
    db.all(
      `SELECT * FROM timetable WHERE UPPER(TRIM(className)) = UPPER(TRIM(?)) ORDER BY day, startTime`,
      [className],
      (err, entries) => {
        if (err) {
          return res.status(500).json({ success: false, message: 'Database error' });
        }
        res.json(entries);
      }
    );
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// GET TIMETABLE FOR SPECIFIC DAY
app.get('/api/timetable/day/:className/:day', (req, res) => {
  try {
    const { className, day } = req.params;
    db.all(
      `SELECT * FROM timetable WHERE UPPER(TRIM(className)) = UPPER(TRIM(?)) AND day = ? ORDER BY startTime`,
      [className, day],
      (err, entries) => {
        if (err) {
          return res.status(500).json({ success: false, message: 'Database error' });
        }
        res.json(entries);
      }
    );
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE TIMETABLE ENTRY
app.delete('/api/timetable/:timetableId', (req, res) => {
  try {
    const { timetableId } = req.params;
    db.run(
      `DELETE FROM timetable WHERE id = ?`,
      [timetableId],
      (err) => {
        if (err) {
          return res.status(500).json({ success: false, message: 'Database error' });
        }
        res.json({ success: true, message: 'Deleted successfully' });
      }
    );
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