import Joi from 'joi';

// User registration schema
export const authSchema = Joi.object({
  name: Joi.string()
    .min(2)
    .max(50)
    .required()
    .messages({
      'string.min': 'Name must be at least 2 characters long',
      'string.max': 'Name cannot be more than 50 characters long',
      'string.empty': 'Name is required',
    }),
    
  email: Joi.string()
    .email()
    .required()
    .messages({
      'string.email': 'Must be a valid email address',
      'string.empty': 'Email is required',
    }),
    
  password: Joi.string()
    .min(6)
    .max(128)
    .pattern(/[A-Z]/, 'uppercase letter')
    .pattern(/[a-z]/, 'lowercase letter')
    .pattern(/[0-9]/, 'number')
    .pattern(/[!@#$%^&*(),.?":{}|<>]/, 'special character')
    .required()
    .messages({
      'string.min': 'Password must be at least 6 characters long',
      'string.max': 'Password cannot be more than 128 characters long',
      'string.pattern.base': 'Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character',
      'string.empty': 'Password is required',
    }),
});

// User login schema
export const loginSchema = Joi.object({
  email: Joi.string()
    .email()
    .required()
    .messages({
      'string.email': 'Must be a valid email address',
      'string.empty': 'Email is required',
    }),
    
  password: Joi.string()
    .required()
    .messages({
      'string.empty': 'Password is required',
    }),
});

// User update schema
export const updateUserSchema = Joi.object({
  name: Joi.string()
    .min(2)
    .max(50)
    .optional(),
    
  email: Joi.string()
    .email()
    .optional(),
    
  role: Joi.string()
    .valid('admin', 'agent', 'manager')
    .optional(),
});

// Password change schema
export const changePasswordSchema = Joi.object({
  currentPassword: Joi.string()
    .required()
    .messages({
      'string.empty': 'Current password is required',
    }),
    
  newPassword: Joi.string()
    .min(6)
    .max(128)
    .pattern(/[A-Z]/, 'uppercase letter')
    .pattern(/[a-z]/, 'lowercase letter')
    .pattern(/[0-9]/, 'number')
    .pattern(/[!@#$%^&*(),.?":{}|<>]/, 'special character')
    .required()
    .messages({
      'string.min': 'New password must be at least 6 characters long',
      'string.max': 'New password cannot be more than 128 characters long',
      'string.pattern.base': 'New password must contain at least one uppercase letter, one lowercase letter, one number, and one special character',
      'string.empty': 'New password is required',
    }),
    
  confirmPassword: Joi.string()
    .required()
    .messages({
      'string.empty': 'Password confirmation is required',
    }),
}).custom((value, helpers) => {
  if (value.newPassword !== value.confirmPassword) {
    return helpers.error('any.invalid', { 
      message: 'Passwords do not match' 
    });
  }
  return value;
}, 'password confirmation');

// Profile update schema
export const profileSchema = Joi.object({
  name: Joi.string()
    .min(2)
    .max(50)
    .required()
    .messages({
      'string.min': 'Name must be at least 2 characters long',
      'string.max': 'Name cannot be more than 50 characters long',
      'string.empty': 'Name is required',
    }),
    
  phone: Joi.string()
    .pattern(/^[+]?[0-9]{10,15}$/)
    .optional()
    .allow('')
    .messages({
      'string.pattern.base': 'Phone number must be valid (10-15 digits, + allowed)',
    }),
    
  title: Joi.string()
    .max(100)
    .optional()
    .allow(''),
    
  bio: Joi.string()
    .max(500)
    .optional()
    .allow(''),
});

// Reset password request schema
export const resetPasswordRequestSchema = Joi.object({
  email: Joi.string()
    .email()
    .required()
    .messages({
      'string.email': 'Must be a valid email address',
      'string.empty': 'Email is required',
    }),
});

// Reset password with token schema
export const resetPasswordSchema = Joi.object({
  token: Joi.string()
    .required()
    .messages({
      'string.empty': 'Reset token is required',
    }),
    
  password: Joi.string()
    .min(6)
    .max(128)
    .pattern(/[A-Z]/, 'uppercase letter')
    .pattern(/[a-z]/, 'lowercase letter')
    .pattern(/[0-9]/, 'number')
    .pattern(/[!@#$%^&*(),.?":{}|<>]/, 'special character')
    .required()
    .messages({
      'string.min': 'Password must be at least 6 characters long',
      'string.max': 'Password cannot be more than 128 characters long',
      'string.pattern.base': 'Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character',
      'string.empty': 'Password is required',
    }),
    
  confirmPassword: Joi.string()
    .required()
    .messages({
      'string.empty': 'Password confirmation is required',
    }),
}).custom((value, helpers) => {
  if (value.password !== value.confirmPassword) {
    return helpers.error('any.invalid', { 
      message: 'Passwords do not match' 
    });
  }
  return value;
}, 'password confirmation');