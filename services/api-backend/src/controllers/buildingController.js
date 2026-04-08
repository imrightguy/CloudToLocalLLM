import { v4 as uuidv4 } from 'uuid';
import { db } from '../database/db.js';
import { buildingsTable, unitsTable, agentsTable } from '../database/schemas.js';

export const buildingController = {
  async getAllBuildings(req, res) {
    try {
      const { page = 1, limit = 10 } = req.query;
      const offset = (page - 1) * limit;

      // Get buildings with units and manager info
      const buildings = await db
        .select({
          id: buildingsTable.id,
          name: buildingsTable.name,
          address: buildingsTable.address,
          totalUnits: buildingsTable.totalUnits,
          occupiedUnits: buildingsTable.occupiedUnits,
          monthlyRevenue: buildingsTable.monthlyRevenue,
          managerId: buildingsTable.managerId,
          createdAt: buildingsTable.createdAt,
          updatedAt: buildingsTable.updatedAt,
        })
        .from(buildingsTable)
        .leftJoin(agentsTable, buildingsTable.managerId.eq(agentsTable.id))
        .limit(Number(limit))
        .offset(offset);

      // Calculate occupancy rates
      const buildingsWithRates = buildings.map(building => ({
        ...building,
        occupancyRate: building.totalUnits > 0 ? building.occupiedUnits / building.totalUnits : 0,
      }));

      // Get total count
      const [{ count }] = await db
        .select({ count: buildingsTable.count() })
        .from(buildingsTable);

      res.json({
        buildings: buildingsWithRates,
        total: count,
        page: Number(page),
        limit: Number(limit),
      });
    } catch (error) {
      console.error('Get buildings error:', error);
      res.status(500).json({
        error: 'Failed to get buildings',
      });
    }
  },

  async getBuildingById(req, res) {
    try {
      const { id } = req.params;

      const building = await db
        .select({
          id: buildingsTable.id,
          name: buildingsTable.name,
          address: buildingsTable.address,
          totalUnits: buildingsTable.totalUnits,
          occupiedUnits: buildingsTable.occupiedUnits,
          monthlyRevenue: buildingsTable.monthlyRevenue,
          managerId: buildingsTable.managerId,
          createdAt: buildingsTable.createdAt,
          updatedAt: buildingsTable.updatedAt,
        })
        .from(buildingsTable)
        .where(buildingsTable.id.eq(id))
        .limit(1);

      if (building.length === 0) {
        return res.status(404).json({
          error: 'Building not found',
        });
      }

      // Get units for this building
      const units = await db
        .select({
          id: unitsTable.id,
          label: unitsTable.label,
          rent: unitsTable.rent,
          status: unitsTable.status,
          amenities: unitsTable.amenities,
          squareFeet: unitsTable.squareFeet,
          bedrooms: unitsTable.bedrooms,
          bathrooms: unitsTable.bathrooms,
          isOccupied: unitsTable.status.eq('occupied'),
        })
        .from(unitsTable)
        .where(unitsTable.buildingId.eq(id));

      const buildingWithUnits = {
        ...building[0],
        units: units.map(unit => ({
          ...unit,
          occupied: unit.isOccupied,
        })),
      };

      res.json({
        building: buildingWithUnits,
      });
    } catch (error) {
      console.error('Get building error:', error);
      res.status(500).json({
        error: 'Failed to get building',
      });
    }
  },

  async createBuilding(req, res) {
    try {
      const {
        name,
        address,
        totalUnits,
        managerId,
        properties = {},
      } = req.body;

      // Validate manager exists if provided
      if (managerId) {
        const manager = await db
          .select({ id: agentsTable.id })
          .from(agentsTable)
          .where(agentsTable.id.eq(managerId))
          .limit(1);

        if (manager.length === 0) {
          return res.status(400).json({
            error: 'Manager not found',
          });
        }
      }

      // Calculate default occupancy (50%)
      const occupiedUnits = Math.floor(totalUnits * 0.5);
      const monthlyRevenue = occupiedUnits * 1500; // Average rent estimate

      const newBuilding = {
        id: uuidv4(),
        name,
        address,
        totalUnits,
        occupiedUnits,
        monthlyRevenue,
        managerId,
        properties,
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      await db.insert(buildingsTable).values(newBuilding);

      // Create default units
      const units = [];
      for (let i = 1; i <= totalUnits; i++) {
        units.push({
          id: uuidv4(),
          buildingId: newBuilding.id,
          label: `${i}00 - 2 1/2`, // Default unit label format
          rent: 1500,
          status: i <= occupiedUnits ? 'occupied' : 'vacant',
          amenities: ['Fridge', 'Stove', 'A/C'],
          squareFeet: 800,
          bedrooms: 2,
          bathrooms: 1,
        });
      }

      await db.insert(unitsTable).values(units);

      // Remove password from response if needed
      const { password, ...buildingWithoutSensitive } = newBuilding;

      res.status(201).json({
        message: 'Building created successfully',
        building: {
          ...buildingWithoutSensitive,
          units,
        },
      });
    } catch (error) {
      console.error('Create building error:', error);
      res.status(500).json({
        error: 'Failed to create building',
      });
    }
  },

  async updateBuilding(req, res) {
    try {
      const { id } = req.params;
      const {
        name,
        address,
        totalUnits,
        managerId,
        properties,
      } = req.body;

      // Check if building exists
      const existingBuilding = await db
        .select({ id: buildingsTable.id })
        .from(buildingsTable)
        .where(buildingsTable.id.eq(id))
        .limit(1);

      if (existingBuilding.length === 0) {
        return res.status(404).json({
          error: 'Building not found',
        });
      }

      // Validate manager exists if provided
      if (managerId) {
        const manager = await db
          .select({ id: agentsTable.id })
          .from(agentsTable)
          .where(agentsTable.id.eq(managerId))
          .limit(1);

        if (manager.length === 0) {
          return res.status(400).json({
            error: 'Manager not found',
          });
        }
      }

      // Update building
      const updateData = {
        name,
        address,
        managerId,
        properties,
        updatedAt: new Date(),
      };

      // Handle unit count changes
      if (totalUnits !== undefined) {
        const currentBuilding = await db
          .select({ totalUnits: buildingsTable.totalUnits })
          .from(buildingsTable)
          .where(buildingsTable.id.eq(id))
          .limit(1);

        if (totalUnits > currentBuilding[0].totalUnits) {
          // Add new units
          const newUnits = [];
          for (let i = currentBuilding[0].totalUnits + 1; i <= totalUnits; i++) {
            newUnits.push({
              id: uuidv4(),
              buildingId: id,
              label: `${i}00 - 2 1/2`,
              rent: 1500,
              status: 'vacant',
              amenities: ['Fridge', 'Stove', 'A/C'],
              squareFeet: 800,
              bedrooms: 2,
              bathrooms: 1,
            });
          }
          await db.insert(unitsTable).values(newUnits);
        }

        updateData.totalUnits = totalUnits;
        // Recalculate occupied units
        const currentOccupied = await db
          .select({ count: unitsTable.count() })
          .from(unitsTable)
          .where(unitsTable.buildingId.eq(id))
          .where(unitsTable.status.eq('occupied'));

        updateData.occupiedUnits = currentOccupied[0].count;
        updateData.monthlyRevenue = currentOccupied[0].count * 1500;
      }

      await db
        .update(buildingsTable)
        .set(updateData)
        .where(buildingsTable.id.eq(id));

      const updatedBuilding = await db
        .select()
        .from(buildingsTable)
        .where(buildingsTable.id.eq(id))
        .limit(1);

      res.json({
        message: 'Building updated successfully',
        building: updatedBuilding[0],
      });
    } catch (error) {
      console.error('Update building error:', error);
      res.status(500).json({
        error: 'Failed to update building',
      });
    }
  },

  async deleteBuilding(req, res) {
    try {
      const { id } = req.params;

      // Check if building exists
      const existingBuilding = await db
        .select({ id: buildingsTable.id })
        .from(buildingsTable)
        .where(buildingsTable.id.eq(id))
        .limit(1);

      if (existingBuilding.length === 0) {
        return res.status(404).json({
          error: 'Building not found',
        });
      }

      // Delete related units first (foreign key constraint)
      await db
        .delete(unitsTable)
        .where(unitsTable.buildingId.eq(id));

      // Delete building
      await db
        .delete(buildingsTable)
        .where(buildingsTable.id.eq(id));

      res.json({
        message: 'Building deleted successfully',
      });
    } catch (error) {
      console.error('Delete building error:', error);
      res.status(500).json({
        error: 'Failed to delete building',
      });
    }
  },
};