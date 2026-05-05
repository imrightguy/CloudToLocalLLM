const Joi = require('joi');

// Building validation schema
const buildingSchema = Joi.object({
  name: Joi.string()
    .min(2)
    .max(100)
    .required()
    .messages({
      'string.min': 'Building name must be at least 2 characters long',
      'string.max': 'Building name cannot be more than 100 characters long',
      'string.empty': 'Building name is required',
    }),

  address: Joi.string()
    .min(5)
    .max(255)
    .required()
    .messages({
      'string.min': 'Address must be at least 5 characters long',
      'string.max': 'Address cannot be more than 255 characters long',
      'string.empty': 'Address is required',
    }),

  city: Joi.string()
    .min(1)
    .max(255)
    .required()
    .messages({
      'string.empty': 'City is required',
    }),

  province: Joi.string()
    .max(10)
    .optional()
    .default('QC'),

  postalCode: Joi.string()
    .max(10)
    .optional()
    .allow(''),

  totalUnits: Joi.number()
    .integer()
    .min(1)
    .max(1000)
    .required()
    .messages({
      'number.base': 'Total units must be a number',
      'number.integer': 'Total units must be an integer',
      'number.min': 'Total units must be at least 1',
      'number.max': 'Total units cannot be more than 1000',
    }),

  occupiedUnits: Joi.number()
    .integer()
    .min(0)
    .max(Joi.ref('totalUnits'))
    .optional()
    .default(0)
    .messages({
      'number.base': 'Occupied units must be a number',
      'number.integer': 'Occupied units must be an integer',
      'number.min': 'Occupied units cannot be negative',
      'number.max': 'Occupied units cannot exceed total units',
    }),

  monthlyRevenue: Joi.number()
    .integer()
    .min(0)
    .optional()
    .default(0)
    .messages({
      'number.base': 'Monthly revenue must be a number',
      'number.integer': 'Monthly revenue must be an integer',
      'number.min': 'Monthly revenue cannot be negative',
    }),

  managerId: Joi.string()
    .guid()
    .optional()
    .allow(null)
    .messages({
      'string.guid': 'Manager ID must be a valid UUID',
    }),

  properties: Joi.object({
    yearBuilt: Joi.number()
      .integer()
      .min(1800)
      .max(new Date().getFullYear())
      .optional()
      .messages({
        'number.base': 'Year built must be a number',
        'number.integer': 'Year built must be an integer',
        'number.min': 'Year built must be after 1800',
        'number.max': 'Year built cannot be in the future',
      }),

    elevator: Joi.boolean().optional(),
    gym: Joi.boolean().optional(),
    pool: Joi.boolean().optional(),
    parking: Joi.boolean().optional(),
    laundry: Joi.boolean().optional(),
    petFriendly: Joi.boolean().optional(),
    security: Joi.boolean().optional(),

    description: Joi.string()
      .max(2000)
      .optional()
      .allow('')
      .messages({
        'string.max': 'Description cannot be more than 2000 characters long',
      }),

    images: Joi.array()
      .items(Joi.string().uri())
      .max(20)
      .optional()
      .messages({
        'array.max': 'Cannot have more than 20 images',
        'string.uri': 'Image URLs must be valid URLs',
      }),

    amenities: Joi.array()
      .items(Joi.string())
      .max(50)
      .optional()
      .messages({
        'array.max': 'Cannot have more than 50 amenities',
      }),
  })
    .default({})
    .messages({
      'object.base': 'Properties must be an object',
    }),
});

// Unit validation schema
const unitSchema = Joi.object({
  buildingId: Joi.string()
    .guid()
    .required()
    .messages({
      'string.guid': 'Building ID must be a valid UUID',
    }),

  label: Joi.string()
    .min(2)
    .max(50)
    .pattern(/^[A-Za-z0-9\- ]+$/)
    .messages({
      'string.min': 'Unit label must be at least 2 characters long',
      'string.max': 'Unit label cannot be more than 50 characters long',
      'string.pattern.base': 'Unit label can only contain letters, numbers, spaces, and hyphens',
    }),

  unitNumber: Joi.string()
    .min(1)
    .max(50)
    .messages({
      'string.empty': 'Unit number is required',
    }),

  rent: Joi.number()
    .integer()
    .min(0)
    .max(100000)
    .messages({
      'number.base': 'Rent must be a number',
      'number.integer': 'Rent must be an integer',
      'number.min': 'Rent cannot be negative',
      'number.max': 'Rent cannot exceed $100,000 per month',
    }),

  rentAmount: Joi.number()
    .min(0)
    .max(100000)
    .messages({
      'number.base': 'Rent amount must be a number',
      'number.min': 'Rent amount cannot be negative',
      'number.max': 'Rent amount cannot exceed $100,000 per month',
    }),

  status: Joi.string()
    .valid('vacant', 'occupied', 'maintenance')
    .default('vacant')
    .messages({
      'any.only': 'Status must be one of: vacant, occupied, maintenance',
    }),

  isAvailable: Joi.boolean(),
  type: Joi.string().valid('studio', '1br', '2br', '3br', '4br', 'other'),

  amenities: Joi.array()
    .items(Joi.string())
    .max(50)
    .optional()
    .default([])
    .messages({
      'array.max': 'Cannot have more than 50 amenities',
    }),

  squareFeet: Joi.number()
    .integer()
    .min(100)
    .max(10000)
    .optional()
    .messages({
      'number.base': 'Square feet must be a number',
      'number.integer': 'Square feet must be an integer',
      'number.min': 'Square feet must be at least 100',
      'number.max': 'Square feet cannot exceed 10,000',
    }),

  sqft: Joi.number()
    .integer()
    .min(0)
    .max(10000)
    .optional(),

  bedrooms: Joi.number()
    .integer()
    .min(0)
    .max(10) // Max 10 bedrooms
    .optional()
    .messages({
      'number.base': 'Bedrooms must be a number',
      'number.integer': 'Bedrooms must be an integer',
      'number.min': 'Bedrooms cannot be negative',
      'number.max': 'Bedrooms cannot exceed 10',
    }),

  bathrooms: Joi.number()
    .integer()
    .min(0)
    .max(10) // Max 10 bathrooms
    .optional()
    .messages({
      'number.base': 'Bathrooms must be a number',
      'number.integer': 'Bathrooms must be an integer',
      'number.min': 'Bathrooms cannot be negative',
      'number.max': 'Bathrooms cannot exceed 10',
    }),

  description: Joi.string()
    .max(2000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Description cannot be more than 2000 characters long',
    }),

  features: Joi.object({
    furnished: Joi.boolean().optional(),
    parkingIncluded: Joi.boolean().optional(),
    airConditioning: Joi.boolean().optional(),
    balcony: Joi.boolean().optional(),
    patio: Joi.boolean().optional(),
    fireplace: Joi.boolean().optional(),
    dishwasher: Joi.boolean().optional(),
    microwave: Joi.boolean().optional(),
    inUnitLaundry: Joi.boolean().optional(),
  })
    .default({})
    .messages({
      'object.base': 'Features must be an object',
    }),

  tenantName: Joi.string()
    .max(200)
    .optional()
    .allow(null, '')
    .messages({
      'string.max': 'Tenant name cannot exceed 200 characters',
    }),

  tenantPhone: Joi.string()
    .pattern(/^\+?[\d\s\-()]{7,20}$/)
    .optional()
    .allow(null, '')
    .messages({
      'string.pattern.base': 'Invalid phone number format',
    }),

  tenantLeaseEnd: Joi.date()
    .iso()
    .optional()
    .allow(null)
    .messages({
      'date.format': 'tenantLeaseEnd must be a valid ISO date',
    }),
});

// Building update schema (partial building schema)
const updateBuildingSchema = Joi.object({
  name: Joi.string()
    .min(2)
    .max(100)
    .optional()
    .messages({
      'string.min': 'Building name must be at least 2 characters long',
      'string.max': 'Building name cannot be more than 100 characters long',
    }),

  address: Joi.string()
    .min(5)
    .max(255)
    .optional()
    .messages({
      'string.min': 'Address must be at least 5 characters long',
      'string.max': 'Address cannot be more than 255 characters long',
    }),

  totalUnits: Joi.number()
    .integer()
    .min(1)
    .max(1000)
    .optional()
    .messages({
      'number.base': 'Total units must be a number',
      'number.integer': 'Total units must be an integer',
      'number.min': 'Total units must be at least 1',
      'number.max': 'Total units cannot be more than 1000',
    }),

  occupiedUnits: Joi.number()
    .integer()
    .min(0)
    .max(Joi.ref('totalUnits'))
    .optional()
    .messages({
      'number.base': 'Occupied units must be a number',
      'number.integer': 'Occupied units must be an integer',
      'number.min': 'Occupied units cannot be negative',
      'number.max': 'Occupied units cannot exceed total units',
    }),

  monthlyRevenue: Joi.number()
    .integer()
    .min(0)
    .optional()
    .messages({
      'number.base': 'Monthly revenue must be a number',
      'number.integer': 'Monthly revenue must be an integer',
      'number.min': 'Monthly revenue cannot be negative',
    }),

  managerId: Joi.string()
    .guid()
    .optional()
    .allow(null)
    .messages({
      'string.guid': 'Manager ID must be a valid UUID',
    }),

  properties: Joi.object({
    yearBuilt: Joi.number()
      .integer()
      .min(1800)
      .max(new Date().getFullYear())
      .optional()
      .messages({
        'number.base': 'Year built must be a number',
        'number.integer': 'Year built must be an integer',
        'number.min': 'Year built must be after 1800',
        'number.max': 'Year built cannot be in the future',
      }),

    elevator: Joi.boolean().optional(),
    gym: Joi.boolean().optional(),
    pool: Joi.boolean().optional(),
    parking: Joi.boolean().optional(),
    laundry: Joi.boolean().optional(),
    petFriendly: Joi.boolean().optional(),
    security: Joi.boolean().optional(),

    description: Joi.string()
      .max(2000)
      .optional()
      .allow('')
      .messages({
        'string.max': 'Description cannot be more than 2000 characters long',
      }),

    images: Joi.array()
      .items(Joi.string().uri())
      .max(20)
      .optional()
      .messages({
        'array.max': 'Cannot have more than 20 images',
        'string.uri': 'Image URLs must be valid URLs',
      }),

    amenities: Joi.array()
      .items(Joi.string())
      .max(50)
      .optional()
      .messages({
        'array.max': 'Cannot have more than 50 amenities',
      }),
  })
    .optional()
    .messages({
      'object.base': 'Properties must be an object',
    }),
});

// Unit update schema
const updateUnitSchema = Joi.object({
  label: Joi.string()
    .min(2)
    .max(50)
    .optional()
    .pattern(/^[A-Za-z0-9\- ]+$/)
    .messages({
      'string.min': 'Unit label must be at least 2 characters long',
      'string.max': 'Unit label cannot be more than 50 characters long',
      'string.pattern.base': 'Unit label can only contain letters, numbers, spaces, and hyphens',
    }),

  rent: Joi.number()
    .integer()
    .min(0)
    .max(100000)
    .optional()
    .messages({
      'number.base': 'Rent must be a number',
      'number.integer': 'Rent must be an integer',
      'number.min': 'Rent cannot be negative',
      'number.max': 'Rent cannot exceed $100,000 per month',
    }),

  status: Joi.string()
    .valid('vacant', 'occupied', 'maintenance')
    .optional()
    .messages({
      'any.only': 'Status must be one of: vacant, occupied, maintenance',
    }),

  amenities: Joi.array()
    .items(Joi.string())
    .max(50)
    .optional()
    .messages({
      'array.max': 'Cannot have more than 50 amenities',
    }),

  squareFeet: Joi.number()
    .integer()
    .min(100)
    .max(10000)
    .optional()
    .messages({
      'number.base': 'Square feet must be a number',
      'number.integer': 'Square feet must be an integer',
      'number.min': 'Square feet must be at least 100',
      'number.max': 'Square feet cannot exceed 10,000',
    }),

  bedrooms: Joi.number()
    .integer()
    .min(0)
    .max(10)
    .optional()
    .messages({
      'number.base': 'Bedrooms must be a number',
      'number.integer': 'Bedrooms must be an integer',
      'number.min': 'Bedrooms cannot be negative',
      'number.max': 'Bedrooms cannot exceed 10',
    }),

  bathrooms: Joi.number()
    .integer()
    .min(0)
    .max(10)
    .optional()
    .messages({
      'number.base': 'Bathrooms must be a number',
      'number.integer': 'Bathrooms must be an integer',
      'number.min': 'Bathrooms cannot be negative',
      'number.max': 'Bathrooms cannot exceed 10',
    }),

  description: Joi.string()
    .max(2000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Description cannot be more than 2000 characters long',
    }),

  features: Joi.object({
    furnished: Joi.boolean().optional(),
    parkingIncluded: Joi.boolean().optional(),
    airConditioning: Joi.boolean().optional(),
    balcony: Joi.boolean().optional(),
    patio: Joi.boolean().optional(),
    fireplace: Joi.boolean().optional(),
    dishwasher: Joi.boolean().optional(),
    microwave: Joi.boolean().optional(),
    inUnitLaundry: Joi.boolean().optional(),
  })
    .optional()
    .messages({
      'object.base': 'Features must be an object',
    }),

  tenantName: Joi.string()
    .max(200)
    .optional()
    .allow(null, '')
    .messages({
      'string.max': 'Tenant name cannot exceed 200 characters',
    }),

  tenantPhone: Joi.string()
    .pattern(/^\+?[\d\s\-()]{7,20}$/)
    .optional()
    .allow(null, '')
    .messages({
      'string.pattern.base': 'Invalid phone number format',
    }),

  tenantLeaseEnd: Joi.date()
    .iso()
    .optional()
    .allow(null)
    .messages({
      'date.format': 'tenantLeaseEnd must be a valid ISO date',
    }),
});

module.exports = {
  buildingSchema, unitSchema, updateBuildingSchema, updateUnitSchema,
};
