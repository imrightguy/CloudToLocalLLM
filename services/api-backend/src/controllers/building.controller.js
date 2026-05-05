const {
  eq, and, desc, asc, ilike, sql,
} = require('drizzle-orm');
const { db } = require('../database/connection');
const { buildingsTable, unitsTable } = require('../database/schema');
const { buildingSchemas } = require('../config/validation-schemas');
const { child } = require('../utils/logger');

const log = child({ controller: 'building' });

// ═══════════════════════════════════════════
//  Building Controllers
// ═══════════════════════════════════════════

// ─── Create Building ───
exports.createBuilding = async (req, res) => {
  try {
    const { error, value } = buildingSchemas.create.body.validate(req.body);
    if (error) {
      return res.status(400).json({
        success: false,
        error: { message: error.details[0].message, code: 'VALIDATION_ERROR' },
      });
    }

    const [building] = await db
      .insert(buildingsTable)
      .values({
        name: value.name,
        address: value.address,
        city: value.city || 'Montréal',
        province: value.province || 'QC',
        postalCode: value.postalCode || null,
        totalUnits: value.totalUnits,
        occupiedUnits: value.occupiedUnits || 0,
        description: value.properties?.description || null,
        properties: value.properties || {},
      })
      .returning();

    res.status(201).json({ success: true, data: building, message: 'Building created successfully' });
  } catch (error) {
    log.error('Error creating building', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'BUILDING_CREATION_FAILED' },
    });
  }
};

// ─── Get Buildings (paginated, searchable) ───
exports.getBuildings = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      search,
      sortBy = 'name',
      sortOrder = 'asc',
    } = req.query;

    const validPage = Math.max(1, parseInt(page));
    const validLimit = Math.min(100, Math.max(1, parseInt(limit)));
    const offset = (validPage - 1) * validLimit;

    // Build conditions
    const conditions = [];
    if (search) {
      conditions.push(
        ilike(buildingsTable.name, `%${search}%`),
      );
    }

    const whereClause = conditions.length > 0 ? and(...conditions) : undefined;

    // Count
    const [{ count: total }] = await db
      .select({ count: sql`count(*)::int` })
      .from(buildingsTable)
      .where(whereClause);

    // Sort
    const allowedSortFields = {
      name: buildingsTable.name,
      address: buildingsTable.address,
      city: buildingsTable.city,
      totalUnits: buildingsTable.totalUnits,
      occupiedUnits: buildingsTable.occupiedUnits,
      createdAt: buildingsTable.createdAt,
      updatedAt: buildingsTable.updatedAt,
    };
    const sortColumn = allowedSortFields[sortBy] || buildingsTable.name;
    const orderFn = sortOrder === 'desc' ? desc : asc;

    // Data
    const buildings = await db
      .select()
      .from(buildingsTable)
      .where(whereClause)
      .orderBy(orderFn(sortColumn))
      .limit(validLimit)
      .offset(offset);

    const totalPages = Math.ceil(total / validLimit);

    res.json({
      success: true,
      data: buildings,
      metadata: {
        total,
        page: validPage,
        limit: validLimit,
        totalPages,
        hasMore: validPage < totalPages,
      },
    });
  } catch (error) {
    log.error('Error fetching buildings', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'BUILDING_FETCH_FAILED' },
    });
  }
};

// ─── Get Building By ID ───
exports.getBuildingById = async (req, res) => {
  try {
    const { id } = req.params;

    const [building] = await db
      .select()
      .from(buildingsTable)
      .where(eq(buildingsTable.id, id))
      .limit(1);

    if (!building) {
      return res.status(404).json({
        success: false,
        error: { message: 'Building not found', code: 'BUILDING_NOT_FOUND' },
      });
    }

    res.json({ success: true, data: building });
  } catch (error) {
    log.error('Error fetching building', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'BUILDING_FETCH_FAILED' },
    });
  }
};

// ─── Update Building ───
exports.updateBuilding = async (req, res) => {
  try {
    const { id } = req.params;
    const { error, value } = buildingSchemas.update.body.validate(req.body);

    if (error) {
      return res.status(400).json({
        success: false,
        error: { message: error.details[0].message, code: 'VALIDATION_ERROR' },
      });
    }

    // Check existence
    const [existing] = await db
      .select()
      .from(buildingsTable)
      .where(eq(buildingsTable.id, id))
      .limit(1);

    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Building not found', code: 'BUILDING_NOT_FOUND' },
      });
    }

    // Build update payload
    const updateData = { updatedAt: new Date() };
    if (value.name !== undefined) {updateData.name = value.name;}
    if (value.address !== undefined) {updateData.address = value.address;}
    if (value.city !== undefined) {updateData.city = value.city;}
    if (value.province !== undefined) {updateData.province = value.province;}
    if (value.postalCode !== undefined) {updateData.postalCode = value.postalCode;}
    if (value.totalUnits !== undefined) {updateData.totalUnits = value.totalUnits;}
    if (value.occupiedUnits !== undefined) {updateData.occupiedUnits = value.occupiedUnits;}
    if (value.description !== undefined) {updateData.description = value.description;}
    if (value.properties !== undefined) {updateData.properties = value.properties;}

    const [updated] = await db
      .update(buildingsTable)
      .set(updateData)
      .where(eq(buildingsTable.id, id))
      .returning();

    res.json({ success: true, data: updated, message: 'Building updated successfully' });
  } catch (error) {
    log.error('Error updating building', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'BUILDING_UPDATE_FAILED' },
    });
  }
};

// ─── Delete Building (soft delete) ───
exports.deleteBuilding = async (req, res) => {
  try {
    const { id } = req.params;

    const [building] = await db
      .select()
      .from(buildingsTable)
      .where(eq(buildingsTable.id, id))
      .limit(1);

    if (!building) {
      return res.status(404).json({
        success: false,
        error: { message: 'Building not found', code: 'BUILDING_NOT_FOUND' },
      });
    }

    // Check for active units
    const [{ count: unitCount }] = await db
      .select({ count: sql`count(*)::int` })
      .from(unitsTable)
      .where(and(eq(unitsTable.buildingId, id), eq(unitsTable.isActive, true)));

    if (unitCount > 0) {
      return res.status(400).json({
        success: false,
        error: { message: 'Cannot delete building with active units', code: 'BUILDING_HAS_UNITS' },
      });
    }

    await db
      .update(buildingsTable)
      .set({ isActive: false, updatedAt: new Date() })
      .where(eq(buildingsTable.id, id));

    res.json({ success: true, data: null, message: 'Building deleted successfully' });
  } catch (error) {
    log.error('Error deleting building', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'BUILDING_DELETE_FAILED' },
    });
  }
};

// ═══════════════════════════════════════════
//  Unit Controllers
// ═══════════════════════════════════════════

// ─── Create Unit ───
exports.createUnit = async (req, res) => {
  try {
    const { error, value } = buildingSchemas.createUnit.body.validate(req.body);
    if (error) {
      return res.status(400).json({
        success: false,
        error: { message: error.details[0].message, code: 'VALIDATION_ERROR' },
      });
    }

    // Check if building exists
    const [building] = await db
      .select()
      .from(buildingsTable)
      .where(eq(buildingsTable.id, value.buildingId))
      .limit(1);

    if (!building) {
      return res.status(404).json({
        success: false,
        error: { message: 'Building not found', code: 'BUILDING_NOT_FOUND' },
      });
    }

    // Convert request contract values into stored unit fields
    const label = value.unitNumber || value.label;
    const rentAmount = value.rentAmount ?? value.rent ?? 0;
    const rentCents = Math.round(rentAmount * 100);
    const status = value.status || ((value.isAvailable ?? true) ? 'vacant' : 'occupied');
    const squareFeet = value.sqft ?? value.squareFeet ?? null;

    const unitInsert = {
      buildingId: value.buildingId,
      label,
      rentCents,
      status,
    };

    if (value.bedrooms !== undefined) { unitInsert.bedrooms = value.bedrooms; }
    if (value.bathrooms !== undefined) { unitInsert.bathrooms = value.bathrooms; }
    if (squareFeet !== null && squareFeet !== undefined) { unitInsert.squareFeet = squareFeet; }
    if (value.description) { unitInsert.description = value.description; }
    if (Array.isArray(value.amenities) && value.amenities.length > 0) { unitInsert.amenities = value.amenities; }
    if (value.tenantName) { unitInsert.tenantName = value.tenantName; }
    if (value.tenantPhone) { unitInsert.tenantPhone = value.tenantPhone; }
    if (value.tenantLeaseEnd) { unitInsert.tenantLeaseEnd = new Date(value.tenantLeaseEnd); }

    const unitInsert = {
      buildingId: value.buildingId,
      label: value.label,
      rentCents,
      status: value.status || 'vacant',
    };

    if (value.bedrooms !== undefined) { unitInsert.bedrooms = value.bedrooms; }
    if (value.bathrooms !== undefined) { unitInsert.bathrooms = value.bathrooms; }
    if (value.squareFeet !== null && value.squareFeet !== undefined) { unitInsert.squareFeet = value.squareFeet; }
    if (value.description) { unitInsert.description = value.description; }
    if (Array.isArray(value.amenities) && value.amenities.length > 0) { unitInsert.amenities = value.amenities; }
    if (value.tenantName) { unitInsert.tenantName = value.tenantName; }
    if (value.tenantPhone) { unitInsert.tenantPhone = value.tenantPhone; }
    if (value.tenantLeaseEnd) { unitInsert.tenantLeaseEnd = new Date(value.tenantLeaseEnd); }

    const [unit] = await db
      .insert(unitsTable)
      .values(unitInsert)
      .returning();

    // Attach display rent in dollars for frontend convenience
    const unitWithRent = {
      ...unit,
      rent: unit.rentCents / 100,
      tenantIsActive: unit.status === 'occupied' && unit.tenantLeaseEnd && new Date(unit.tenantLeaseEnd) > new Date(),
    };

    res.status(201).json({ success: true, data: unitWithRent, message: 'Unit created successfully' });
  } catch (error) {
    log.error('Error creating unit', { error: error.message });

    if (error.code === '23503') {
      return res.status(400).json({
        success: false,
        error: { message: 'Building not found', code: 'FOREIGN_KEY_VIOLATION' },
      });
    }

    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'UNIT_CREATION_FAILED' },
    });
  }
};

// ─── Get Units (filterable by buildingId/status) ───
exports.getUnits = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      buildingId,
      status,
      sortBy = 'label',
      sortOrder = 'asc',
    } = req.query;

    const validPage = Math.max(1, parseInt(page));
    const validLimit = Math.min(100, Math.max(1, parseInt(limit)));
    const offset = (validPage - 1) * validLimit;

    // Build conditions
    const conditions = [];
    if (buildingId) {conditions.push(eq(unitsTable.buildingId, buildingId));}
    if (status) {conditions.push(eq(unitsTable.status, status));}

    const whereClause = conditions.length > 0 ? and(...conditions) : undefined;

    // Count
    const [{ count: total }] = await db
      .select({ count: sql`count(*)::int` })
      .from(unitsTable)
      .where(whereClause);

    // Sort
    const allowedSortFields = {
      label: unitsTable.label,
      status: unitsTable.status,
      rentCents: unitsTable.rentCents,
      bedrooms: unitsTable.bedrooms,
      squareFeet: unitsTable.squareFeet,
      createdAt: unitsTable.createdAt,
      updatedAt: unitsTable.updatedAt,
    };
    const sortColumn = allowedSortFields[sortBy] || unitsTable.label;
    const orderFn = sortOrder === 'desc' ? desc : asc;

    // Data
    const units = await db
      .select()
      .from(unitsTable)
      .where(whereClause)
      .orderBy(orderFn(sortColumn))
      .limit(validLimit)
      .offset(offset);

    // Attach display rent in dollars for each unit
    const unitsWithRent = units.map((unit) => ({
      ...unit,
      rent: unit.rentCents / 100,
      tenantIsActive: unit.status === 'occupied' && unit.tenantLeaseEnd && new Date(unit.tenantLeaseEnd) > new Date(),
    }));

    const totalPages = Math.ceil(total / validLimit);

    res.json({
      success: true,
      data: unitsWithRent,
      metadata: {
        total,
        page: validPage,
        limit: validLimit,
        totalPages,
        hasMore: validPage < totalPages,
      },
    });
  } catch (error) {
    log.error('Error fetching units', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'UNIT_FETCH_FAILED' },
    });
  }
};

// ─── Get Unit By ID ───
exports.getUnitById = async (req, res) => {
  try {
    const { id } = req.params;

    const [unit] = await db
      .select()
      .from(unitsTable)
      .where(eq(unitsTable.id, id))
      .limit(1);

    if (!unit) {
      return res.status(404).json({
        success: false,
        error: { message: 'Unit not found', code: 'UNIT_NOT_FOUND' },
      });
    }

    // Attach display rent in dollars
    const unitWithRent = {
      ...unit,
      rent: unit.rentCents / 100,
      tenantIsActive: unit.status === 'occupied' && unit.tenantLeaseEnd && new Date(unit.tenantLeaseEnd) > new Date(),
    };

    res.json({ success: true, data: unitWithRent });
  } catch (error) {
    log.error('Error fetching unit', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'UNIT_FETCH_FAILED' },
    });
  }
};

// ─── Update Unit ───
exports.updateUnit = async (req, res) => {
  try {
    const { id } = req.params;
    const { error, value } = buildingSchemas.updateUnit.body.validate(req.body);

    if (error) {
      return res.status(400).json({
        success: false,
        error: { message: error.details[0].message, code: 'VALIDATION_ERROR' },
      });
    }

    // Check existence
    const [existing] = await db
      .select()
      .from(unitsTable)
      .where(eq(unitsTable.id, id))
      .limit(1);

    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Unit not found', code: 'UNIT_NOT_FOUND' },
      });
    }

    // Build update payload
    const updateData = { updatedAt: new Date() };
    if (value.label !== undefined) {updateData.label = value.label;}
    if (value.rent !== undefined) {updateData.rentCents = value.rent * 100;}
    if (value.status !== undefined) {updateData.status = value.status;}
    if (value.bedrooms !== undefined) {updateData.bedrooms = value.bedrooms;}
    if (value.bathrooms !== undefined) {updateData.bathrooms = value.bathrooms;}
    if (value.squareFeet !== undefined) {updateData.squareFeet = value.squareFeet;}
    if (value.description !== undefined) {updateData.description = value.description;}
    if (value.amenities !== undefined) {updateData.amenities = value.amenities;}
    if (value.tenantName !== undefined) {updateData.tenantName = value.tenantName || null;}
    if (value.tenantPhone !== undefined) {updateData.tenantPhone = value.tenantPhone || null;}
    if (value.tenantLeaseEnd !== undefined) {
      updateData.tenantLeaseEnd = value.tenantLeaseEnd ? new Date(value.tenantLeaseEnd) : null;
    }

    const [updated] = await db
      .update(unitsTable)
      .set(updateData)
      .where(eq(unitsTable.id, id))
      .returning();

    // Attach display rent in dollars
    const updatedWithRent = {
      ...updated,
      rent: updated.rentCents / 100,
      tenantIsActive: updated.status === 'occupied' && updated.tenantLeaseEnd && new Date(updated.tenantLeaseEnd) > new Date(),
    };

    res.json({ success: true, data: updatedWithRent, message: 'Unit updated successfully' });
  } catch (error) {
    log.error('Error updating unit', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'UNIT_UPDATE_FAILED' },
    });
  }
};

// ─── Delete Unit (soft delete) ───
exports.deleteUnit = async (req, res) => {
  try {
    const { id } = req.params;

    const [unit] = await db
      .select()
      .from(unitsTable)
      .where(eq(unitsTable.id, id))
      .limit(1);

    if (!unit) {
      return res.status(404).json({
        success: false,
        error: { message: 'Unit not found', code: 'UNIT_NOT_FOUND' },
      });
    }

    await db
      .update(unitsTable)
      .set({ isActive: false, updatedAt: new Date() })
      .where(eq(unitsTable.id, id));

    res.json({ success: true, data: null, message: 'Unit deleted successfully' });
  } catch (error) {
    log.error('Error deleting unit', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'UNIT_DELETE_FAILED' },
    });
  }
};
