const { db } = require('../database/connection');
const { buildingSchema, unitSchema, updateBuildingSchema, updateUnitSchema } = require('../models/building');
const { successResponse, errorResponse } = require('../utils/apiResponse');
const { v4: uuidv4 } = require('uuid');

// Building Controllers
exports.createBuilding = async (req, res) => {
  try {
    const { error, value } = buildingSchema.validate(req.body);
    if (error) {
      return res.status(400).json(errorResponse({
        message: error.details[0].message,
        code: 'VALIDATION_ERROR'
      }));
    }

    const buildingId = uuidv4();
    const now = new Date();
    
    const building = {
      id: buildingId,
      name: value.name,
      address: value.address,
      totalUnits: value.totalUnits,
      occupiedUnits: value.occupiedUnits || 0,
      monthlyRevenue: value.monthlyRevenue || 0,
      managerId: value.managerId,
      properties: value.properties || {},
      createdAt: now,
      updatedAt: now,
    };

    const [result] = await db('buildings').insert(building).returning('*');
    
    res.status(201).json(successResponse({
      data: result,
      message: 'Building created successfully'
    }));
  } catch (error) {
    console.error('Error creating building:', error);
    res.status(500).json(errorResponse({
      message: 'Internal server error',
      code: 'BUILDING_CREATION_FAILED'
    }));
  }
};

exports.getBuildings = async (req, res) => {
  try {
    const { page = 1, limit = 20, search, sortBy = 'name', sortOrder = 'asc' } = req.query;
    
    let query = db('buildings').select('*');
    
    if (search) {
      query = query.whereRaw(`
        LOWER(name) LIKE LOWER(?) OR 
        LOWER(address) LIKE LOWER(?)
      `, [`%${search}%`, `%${search}%`]);
    }
    
    const countQuery = query.clone();
    const [totalCount] = await countQuery.count('* as count').then();
    
    const offset = (page - 1) * limit;
    const orderClause = `${sortBy} ${sortOrder}`;
    
    const [buildings] = await query
      .orderBy(orderClause)
      .limit(limit)
      .offset(offset);
    
    const totalPages = Math.ceil(totalCount / limit);
    
    res.json(successResponse({
      data: buildings,
      metadata: {
        total: parseInt(totalCount),
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages,
        hasMore: page < totalPages
      }
    }));
  } catch (error) {
    console.error('Error fetching buildings:', error);
    res.status(500).json(errorResponse({
      message: 'Internal server error',
      code: 'BUILDING_FETCH_FAILED'
    }));
  }
};

exports.getBuildingById = async (req, res) => {
  try {
    const { id } = req.params;
    
    const [building] = await db('buildings')
      .select('*')
      .where({ id })
      .limit(1);
    
    if (!building) {
      return res.status(404).json(errorResponse({
        message: 'Building not found',
        code: 'BUILDING_NOT_FOUND'
      }));
    }
    
    res.json(successResponse({
      data: building
    }));
  } catch (error) {
    console.error('Error fetching building:', error);
    res.status(500).json(errorResponse({
      message: 'Internal server error',
      code: 'BUILDING_FETCH_FAILED'
    }));
  }
};

exports.updateBuilding = async (req, res) => {
  try {
    const { id } = req.params;
    const { error, value } = updateBuildingSchema.validate(req.body);
    
    if (error) {
      return res.status(400).json(errorResponse({
        message: error.details[0].message,
        code: 'VALIDATION_ERROR'
      }));
    }
    
    const [existingBuilding] = await db('buildings')
      .select('*')
      .where({ id })
      .limit(1);
    
    if (!existingBuilding) {
      return res.status(404).json(errorResponse({
        message: 'Building not found',
        code: 'BUILDING_NOT_FOUND'
      }));
    }
    
    const updateData = {
      ...value,
      updatedAt: new Date()
    };
    
    const [updatedBuilding] = await db('buildings')
      .update(updateData)
      .where({ id })
      .returning('*');
    
    res.json(successResponse({
      data: updatedBuilding,
      message: 'Building updated successfully'
    }));
  } catch (error) {
    console.error('Error updating building:', error);
    res.status(500).json(errorResponse({
      message: 'Internal server error',
      code: 'BUILDING_UPDATE_FAILED'
    }));
  }
};

exports.deleteBuilding = async (req, res) => {
  try {
    const { id } = req.params;
    
    const [building] = await db('buildings')
      .select('*')
      .where({ id })
      .limit(1);
    
    if (!building) {
      return res.status(404).json(errorResponse({
        message: 'Building not found',
        code: 'BUILDING_NOT_FOUND'
      }));
    }
    
    // Check if there are any units associated with this building
    const [units] = await db('units')
      .select('*')
      .where({ buildingId: id })
      .limit(1);
    
    if (units) {
      return res.status(400).json(errorResponse({
        message: 'Cannot delete building with associated units',
        code: 'BUILDING_HAS_UNITS'
      }));
    }
    
    await db('buildings').delete().where({ id });
    
    res.json(successResponse({
      message: 'Building deleted successfully'
    }));
  } catch (error) {
    console.error('Error deleting building:', error);
    res.status(500).json(errorResponse({
      message: 'Internal server error',
      code: 'BUILDING_DELETE_FAILED'
    }));
  }
};

// Unit Controllers
exports.createUnit = async (req, res) => {
  try {
    const { error, value } = unitSchema.validate(req.body);
    if (error) {
      return res.status(400).json(errorResponse({
        message: error.details[0].message,
        code: 'VALIDATION_ERROR'
      }));
    }

    const unitId = uuidv4();
    const now = new Date();
    
    const unit = {
      id: unitId,
      buildingId: value.buildingId,
      label: value.label,
      rent: value.rent,
      status: value.status,
      amenities: value.amenities || [],
      squareFeet: value.squareFeet,
      bedrooms: value.bedrooms,
      bathrooms: value.bathrooms,
      description: value.description || '',
      features: value.features || {},
      createdAt: now,
      updatedAt: now,
    };

    // Check if building exists
    const [building] = await db('buildings')
      .select('*')
      .where({ id: value.buildingId })
      .limit(1);
    
    if (!building) {
      return res.status(404).json(errorResponse({
        message: 'Building not found',
        code: 'BUILDING_NOT_FOUND'
      }));
    }

    const [result] = await db('units').insert(unit).returning('*');
    
    res.status(201).json(successResponse({
      data: result,
      message: 'Unit created successfully'
    }));
  } catch (error) {
    console.error('Error creating unit:', error);
    res.status(500).json(errorResponse({
      message: 'Internal server error',
      code: 'UNIT_CREATION_FAILED'
    }));
  }
};

exports.getUnits = async (req, res) => {
  try {
    const { 
      page = 1, 
      limit = 20, 
      search, 
      buildingId, 
      status, 
      sortBy = 'label', 
      sortOrder = 'asc' 
    } = req.query;
    
    let query = db('units').select('*');
    
    if (buildingId) {
      query = query.where({ buildingId });
    }
    
    if (status) {
      query = query.where({ status });
    }
    
    if (search) {
      query = query.whereRaw(`
        LOWER(label) LIKE LOWER(?) OR 
        LOWER(description) LIKE LOWER(?)
      `, [`%${search}%`, `%${search}%`]);
    }
    
    const countQuery = query.clone();
    const [totalCount] = await countQuery.count('* as count').then();
    
    const offset = (page - 1) * limit;
    const orderClause = `${sortBy} ${sortOrder}`;
    
    const [units] = await query
      .orderBy(orderClause)
      .limit(limit)
      .offset(offset);
    
    const totalPages = Math.ceil(totalCount / limit);
    
    res.json(successResponse({
      data: units,
      metadata: {
        total: parseInt(totalCount),
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages,
        hasMore: page < totalPages
      }
    }));
  } catch (error) {
    console.error('Error fetching units:', error);
    res.status(500).json(errorResponse({
      message: 'Internal server error',
      code: 'UNIT_FETCH_FAILED'
    }));
  }
};

exports.getUnitById = async (req, res) => {
  try {
    const { id } = req.params;
    
    const [unit] = await db('units')
      .select('*')
      .where({ id })
      .limit(1);
    
    if (!unit) {
      return res.status(404).json(errorResponse({
        message: 'Unit not found',
        code: 'UNIT_NOT_FOUND'
      }));
    }
    
    res.json(successResponse({
      data: unit
    }));
  } catch (error) {
    console.error('Error fetching unit:', error);
    res.status(500).json(errorResponse({
      message: 'Internal server error',
      code: 'UNIT_FETCH_FAILED'
    }));
  }
};

exports.updateUnit = async (req, res) => {
  try {
    const { id } = req.params;
    const { error, value } = updateUnitSchema.validate(req.body);
    
    if (error) {
      return res.status(400).json(errorResponse({
        message: error.details[0].message,
        code: 'VALIDATION_ERROR'
      }));
    }
    
    const [existingUnit] = await db('units')
      .select('*')
      .where({ id })
      .limit(1);
    
    if (!existingUnit) {
      return res.status(404).json(errorResponse({
        message: 'Unit not found',
        code: 'UNIT_NOT_FOUND'
      }));
    }
    
    const updateData = {
      ...value,
      updatedAt: new Date()
    };
    
    const [updatedUnit] = await db('units')
      .update(updateData)
      .where({ id })
      .returning('*');
    
    res.json(successResponse({
      data: updatedUnit,
      message: 'Unit updated successfully'
    }));
  } catch (error) {
    console.error('Error updating unit:', error);
    res.status(500).json(errorResponse({
      message: 'Internal server error',
      code: 'UNIT_UPDATE_FAILED'
    }));
  }
};

exports.deleteUnit = async (req, res) => {
  try {
    const { id } = req.params;
    
    const [unit] = await db('units')
      .select('*')
      .where({ id })
      .limit(1);
    
    if (!unit) {
      return res.status(404).json(errorResponse({
        message: 'Unit not found',
        code: 'UNIT_NOT_FOUND'
      }));
    }
    
    await db('units').delete().where({ id });
    
    res.json(successResponse({
      message: 'Unit deleted successfully'
    }));
  } catch (error) {
    console.error('Error deleting unit:', error);
    res.status(500).json(errorResponse({
      message: 'Internal server error',
      code: 'UNIT_DELETE_FAILED'
    }));
  }
};