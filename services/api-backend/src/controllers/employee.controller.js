const { db } = require('../database/connection');
const { employeesTable, employeeAssignmentsTable } = require('../database/schema');
const { eq, and, desc, asc, ilike, sql } = require('drizzle-orm');

// ─── Create Employee ───
exports.createEmployee = async (req, res) => {
  try {
    const { firstName, lastName, phone, email } = req.body;

    if (!firstName || !lastName || !phone) {
      return res.status(400).json({
        success: false,
        error: { message: 'firstName, lastName, and phone are required', code: 'VALIDATION_ERROR' },
      });
    }

    const [employee] = await db.insert(employeesTable).values({
      firstName,
      lastName,
      phone,
      email: email || null,
      isActive: true,
    }).returning();

    res.status(201).json({
      success: true,
      data: employee,
      message: 'Employee created successfully',
    });
  } catch (error) {
    console.error('Error creating employee:', error);
    if (error.code === '23505') {
      return res.status(409).json({
        success: false,
        error: { message: 'An employee with this phone number already exists', code: 'DUPLICATE_PHONE' },
      });
    }
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'EMPLOYEE_CREATION_FAILED' },
    });
  }
};

// ─── Get Employees (paginated) ───
exports.getEmployees = async (req, res) => {
  try {
    const { page = 1, limit = 20, search, isActive } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    const conditions = [];
    if (search) {
      conditions.push(
        ilike(employeesTable.firstName, `%${search}%`),
      );
    }
    if (isActive !== undefined) {
      conditions.push(eq(employeesTable.isActive, isActive === 'true'));
    }

    const whereClause = conditions.length > 0 ? and(...conditions) : undefined;

    // Count query
    const countResult = await db.select({ count: sql`count(*)::int` })
      .from(employeesTable)
      .where(whereClause);
    const total = countResult[0]?.count || 0;

    // Data query
    const employees = await db.select()
      .from(employeesTable)
      .where(whereClause)
      .orderBy(asc(employeesTable.lastName), asc(employeesTable.firstName))
      .limit(parseInt(limit))
      .offset(offset);

    const totalPages = Math.ceil(total / parseInt(limit));

    res.json({
      success: true,
      data: employees,
      message: 'Employees retrieved successfully',
      metadata: {
        total,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages,
        hasMore: parseInt(page) < totalPages,
      },
    });
  } catch (error) {
    console.error('Error fetching employees:', error);
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'EMPLOYEE_FETCH_FAILED' },
    });
  }
};

// ─── Get Employee By ID ───
exports.getEmployeeById = async (req, res) => {
  try {
    const { id } = req.params;

    const [employee] = await db.select()
      .from(employeesTable)
      .where(eq(employeesTable.id, id))
      .limit(1);

    if (!employee) {
      return res.status(404).json({
        success: false,
        error: { message: 'Employee not found', code: 'EMPLOYEE_NOT_FOUND' },
      });
    }

    res.json({
      success: true,
      data: employee,
      message: 'Employee retrieved successfully',
    });
  } catch (error) {
    console.error('Error fetching employee:', error);
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'EMPLOYEE_FETCH_FAILED' },
    });
  }
};

// ─── Update Employee ───
exports.updateEmployee = async (req, res) => {
  try {
    const { id } = req.params;
    const { firstName, lastName, phone, email, isActive } = req.body;

    const [existing] = await db.select()
      .from(employeesTable)
      .where(eq(employeesTable.id, id))
      .limit(1);

    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Employee not found', code: 'EMPLOYEE_NOT_FOUND' },
      });
    }

    const updateData = { updatedAt: new Date() };
    if (firstName !== undefined) updateData.firstName = firstName;
    if (lastName !== undefined) updateData.lastName = lastName;
    if (phone !== undefined) updateData.phone = phone;
    if (email !== undefined) updateData.email = email;
    if (isActive !== undefined) updateData.isActive = isActive;

    const [updated] = await db.update(employeesTable)
      .set(updateData)
      .where(eq(employeesTable.id, id))
      .returning();

    res.json({
      success: true,
      data: updated,
      message: 'Employee updated successfully',
    });
  } catch (error) {
    console.error('Error updating employee:', error);
    if (error.code === '23505') {
      return res.status(409).json({
        success: false,
        error: { message: 'An employee with this phone number already exists', code: 'DUPLICATE_PHONE' },
      });
    }
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'EMPLOYEE_UPDATE_FAILED' },
    });
  }
};

// ─── Delete Employee (soft delete) ───
exports.deleteEmployee = async (req, res) => {
  try {
    const { id } = req.params;

    const [existing] = await db.select()
      .from(employeesTable)
      .where(eq(employeesTable.id, id))
      .limit(1);

    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Employee not found', code: 'EMPLOYEE_NOT_FOUND' },
      });
    }

    await db.update(employeesTable)
      .set({ isActive: false, updatedAt: new Date() })
      .where(eq(employeesTable.id, id));

    res.json({
      success: true,
      data: null,
      message: 'Employee deleted successfully',
    });
  } catch (error) {
    console.error('Error deleting employee:', error);
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'EMPLOYEE_DELETE_FAILED' },
    });
  }
};

// ─── Assign Employee to Building ───
exports.assignEmployee = async (req, res) => {
  try {
    const { buildingId, employeeId, role } = req.body;

    if (!buildingId || !employeeId) {
      return res.status(400).json({
        success: false,
        error: { message: 'buildingId and employeeId are required', code: 'VALIDATION_ERROR' },
      });
    }

    const validRoles = ['primary', 'backup'];
    const assignmentRole = role || 'primary';
    if (!validRoles.includes(assignmentRole)) {
      return res.status(400).json({
        success: false,
        error: { message: 'role must be "primary" or "backup"', code: 'VALIDATION_ERROR' },
      });
    }

    const [assignment] = await db.insert(employeeAssignmentsTable).values({
      employeeId,
      buildingId,
      role: assignmentRole,
      isActive: true,
    }).returning();

    res.status(201).json({
      success: true,
      data: assignment,
      message: 'Employee assigned to building successfully',
    });
  } catch (error) {
    console.error('Error assigning employee:', error);
    if (error.code === '23503') {
      return res.status(400).json({
        success: false,
        error: { message: 'Invalid employeeId or buildingId', code: 'FOREIGN_KEY_ERROR' },
      });
    }
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'ASSIGNMENT_FAILED' },
    });
  }
};

// ─── Remove Assignment ───
exports.removeAssignment = async (req, res) => {
  try {
    const { id } = req.params;

    const [existing] = await db.select()
      .from(employeeAssignmentsTable)
      .where(eq(employeeAssignmentsTable.id, id))
      .limit(1);

    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Assignment not found', code: 'ASSIGNMENT_NOT_FOUND' },
      });
    }

    await db.delete(employeeAssignmentsTable)
      .where(eq(employeeAssignmentsTable.id, id));

    res.json({
      success: true,
      data: null,
      message: 'Assignment removed successfully',
    });
  } catch (error) {
    console.error('Error removing assignment:', error);
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'ASSIGNMENT_REMOVAL_FAILED' },
    });
  }
};

// ─── Get Building Employees ───
exports.getBuildingEmployees = async (req, res) => {
  try {
    const { buildingId } = req.params;

    const employees = await db.select({
      id: employeesTable.id,
      firstName: employeesTable.firstName,
      lastName: employeesTable.lastName,
      phone: employeesTable.phone,
      email: employeesTable.email,
      isActive: employeesTable.isActive,
      assignmentId: employeeAssignmentsTable.id,
      role: employeeAssignmentsTable.role,
      assignedAt: employeeAssignmentsTable.createdAt,
    })
      .from(employeeAssignmentsTable)
      .innerJoin(employeesTable, eq(employeeAssignmentsTable.employeeId, employeesTable.id))
      .where(
        and(
          eq(employeeAssignmentsTable.buildingId, buildingId),
          eq(employeeAssignmentsTable.isActive, true),
        ),
      )
      .orderBy(asc(employeeAssignmentsTable.role), asc(employeesTable.lastName));

    res.json({
      success: true,
      data: employees,
      message: 'Building employees retrieved successfully',
    });
  } catch (error) {
    console.error('Error fetching building employees:', error);
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'BUILDING_EMPLOYEES_FETCH_FAILED' },
    });
  }
};
