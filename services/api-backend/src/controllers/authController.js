import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../database/db.js';
import { usersTable } from '../database/schemas.js';

const JWT_SECRET = process.env.JWT_SECRET || 'immogestion-secret-key';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';

/**
 * Register a new user
 * @param {Object} req - Request object
 * @param {Object} res - Response object
 */
export const authController = {
  async register(req, res) {
    try {
      const { name, email, password } = req.body;

      // Check if user already exists
      const existingUser = await db
        .select({ id: usersTable.id })
        .from(usersTable)
        .where(usersTable.email.eq(email))
        .limit(1);

      if (existingUser.length > 0) {
        return res.status(400).json({
          error: 'Email already registered',
        });
      }

      // Hash password
      const hashedPassword = await bcrypt.hash(password, 12);

      // Create user
      const newUser = {
        id: uuidv4(),
        name,
        email,
        password: hashedPassword,
        role: 'agent',
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      await db.insert(usersTable).values(newUser);

      // Generate JWT
      const token = jwt.sign(
        { userId: newUser.id, email: newUser.email, role: newUser.role },
        JWT_SECRET,
        { expiresIn: JWT_EXPIRES_IN }
      );

      // Remove password from response
      const { password: _, ...userWithoutPassword } = newUser;

      res.status(201).json({
        message: 'User registered successfully',
        user: userWithoutPassword,
        token,
      });
    } catch (error) {
      console.error('Registration error:', error);
      res.status(500).json({
        error: 'Failed to register user',
      });
    }
  },

  async login(req, res) {
    try {
      const { email, password } = req.body;

      // Find user by email
      const user = await db
        .select()
        .from(usersTable)
        .where(usersTable.email.eq(email))
        .limit(1);

      if (user.length === 0) {
        return res.status(401).json({
          error: 'Invalid credentials',
        });
      }

      // Check password
      const isValidPassword = await bcrypt.compare(password, user[0].password);
      if (!isValidPassword) {
        return res.status(401).json({
          error: 'Invalid credentials',
        });
      }

      // Generate JWT
      const token = jwt.sign(
        { userId: user[0].id, email: user[0].email, role: user[0].role },
        JWT_SECRET,
        { expiresIn: JWT_EXPIRES_IN }
      );

      // Remove password from response
      const { password: _, ...userWithoutPassword } = user[0];

      res.json({
        message: 'Login successful',
        user: userWithoutPassword,
        token,
      });
    } catch (error) {
      console.error('Login error:', error);
      res.status(500).json({
        error: 'Failed to login',
      });
    }
  },

  async logout(req, res) {
    try {
      // For JWT, logout is client-side by storing/expiring the token
      // In a real application, you might want to implement token blacklisting
      res.json({
        message: 'Logout successful',
      });
    } catch (error) {
      console.error('Logout error:', error);
      res.status(500).json({
        error: 'Failed to logout',
      });
    }
  },

  async getCurrentUser(req, res) {
    try {
      // Extract token from Authorization header
      const authHeader = req.headers.authorization;
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({
          error: 'No token provided',
        });
      }

      const token = authHeader.substring(7);

      // Verify token
      const decoded = jwt.verify(token, JWT_SECRET);

      // Get user from database
      const user = await db
        .select({
          id: usersTable.id,
          name: usersTable.name,
          email: usersTable.email,
          role: usersTable.role,
          createdAt: usersTable.createdAt,
          updatedAt: usersTable.updatedAt,
        })
        .from(usersTable)
        .where(usersTable.id.eq(decoded.userId))
        .limit(1);

      if (user.length === 0) {
        return res.status(404).json({
          error: 'User not found',
        });
      }

      res.json({
        user: user[0],
      });
    } catch (error) {
      console.error('Get current user error:', error);
      if (error.name === 'JsonWebTokenError') {
        return res.status(401).json({
          error: 'Invalid token',
        });
      }
      res.status(500).json({
        error: 'Failed to get current user',
      });
    }
  },
};