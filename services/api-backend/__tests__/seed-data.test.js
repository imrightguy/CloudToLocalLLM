const fs = require('fs');
const path = require('path');

const loadJson = (file) => JSON.parse(
  fs.readFileSync(path.join(__dirname, '../scripts/seed-data', file), 'utf8'),
);

describe('Seed Data Validation', () => {
  describe('buildings.json', () => {
    let buildings;
    beforeAll(() => { buildings = loadJson('buildings.json'); });

    it('should have exactly 3 buildings', () => {
      expect(buildings).toHaveLength(3);
    });

    it('should all be in Quebec', () => {
      buildings.forEach((b) => {
        expect(b.province).toBe('QC');
        expect(['Montréal', 'Québec', 'Laval', 'Gatineau']).toContain(b.city);
      });
    });

    it('should have valid postal codes', () => {
      const postalRegex = /^[A-Z]\d[A-Z] \d[A-Z]\d$/;
      buildings.forEach((b) => {
        expect(b.postalCode).toMatch(postalRegex);
      });
    });

    it('should have French names and descriptions', () => {
      buildings.forEach((b) => {
        expect(b.name).toBeTruthy();
        expect(b.description).toBeTruthy();
      });
    });
  });

  describe('units.json', () => {
    let units;
    beforeAll(() => { units = loadJson('units.json'); });

    it('should have 20+ units', () => {
      expect(units.length).toBeGreaterThanOrEqual(20);
    });

    it('should reference valid building indices (0-2)', () => {
      units.forEach((u) => {
        expect(u.buildingIndex).toBeGreaterThanOrEqual(0);
        expect(u.buildingIndex).toBeLessThanOrEqual(2);
      });
    });

    it('should have varied statuses', () => {
      const statuses = new Set(units.map((u) => u.status));
      expect(statuses).toContain('occupied');
      expect(statuses).toContain('vacant');
      expect(statuses).toContain('maintenance');
    });

    it('should have valid rent amounts (in cents)', () => {
      units.forEach((u) => {
        expect(u.rentCents).toBeGreaterThan(0);
        expect(u.rentCents).toBeLessThan(500000);
      });
    });

    it('occupied units should have tenant info', () => {
      units.filter((u) => u.status === 'occupied').forEach((u) => {
        expect(u.tenantName).toBeTruthy();
        expect(u.tenantPhone).toBeTruthy();
        expect(u.tenantLeaseEnd).toBeTruthy();
      });
    });
  });

  describe('employees.json', () => {
    let employees;
    beforeAll(() => { employees = loadJson('employees.json'); });

    it('should have exactly 3 employees', () => {
      expect(employees).toHaveLength(3);
    });

    it('should have French names', () => {
      employees.forEach((e) => {
        expect(e.firstName).toBeTruthy();
        expect(e.lastName).toBeTruthy();
      });
    });

    it('should have valid Quebec phone numbers', () => {
      employees.forEach((e) => {
        expect(e.phone).toMatch(/^\+1514\d{7}$/);
      });
    });
  });

  describe('leads.json', () => {
    let leads;
    beforeAll(() => { leads = loadJson('leads.json'); });

    it('should have 10 leads', () => {
      expect(leads).toHaveLength(10);
    });

    it('should have varied stages', () => {
      const stages = new Set(leads.map((l) => l.stage));
      expect(stages.size).toBeGreaterThanOrEqual(5);
    });

    it('should all have French language preference', () => {
      leads.forEach((l) => {
        expect(l.language).toBe('fr');
      });
    });

    it('should include qualification metadata on at least one lead', () => {
      const qualifiedLead = leads.find((l) => l.qualificationState);
      expect(qualifiedLead).toBeTruthy();
      expect(qualifiedLead.qualificationReasonCode).toBeTruthy();
      expect(qualifiedLead.qualificationReasonNote).toBeTruthy();
    });

    it('should have valid sources', () => {
      const validSources = ['facebook', 'website', 'referral', 'other'];
      leads.forEach((l) => {
        expect(validSources).toContain(l.source);
      });
    });
  });

  describe('visits.json', () => {
    let visits;
    beforeAll(() => { visits = loadJson('visits.json'); });

    it('should have 8 visits', () => {
      expect(visits).toHaveLength(8);
    });

    it('should have both past and future visits', () => {
      const now = new Date();
      const past = visits.filter((v) => new Date(v.dateTime) < now);
      const future = visits.filter((v) => new Date(v.dateTime) >= now);
      expect(past.length).toBeGreaterThan(0);
      expect(future.length).toBeGreaterThan(0);
    });

    it('should have varied statuses', () => {
      const statuses = new Set(visits.map((v) => v.status));
      expect(statuses).toContain('completed');
      expect(statuses).toContain('scheduled');
    });
  });

  describe('leases.json', () => {
    let leases;
    beforeAll(() => { leases = loadJson('leases.json'); });

    it('should have 5+ active, 2 expired, 1 draft leases', () => {
      expect(leases.length).toBeGreaterThanOrEqual(8);
      const active = leases.filter((l) => l.status === 'active').length;
      const expired = leases.filter((l) => l.status === 'expired').length;
      const draft = leases.filter((l) => l.status === 'draft').length;
      expect(active).toBeGreaterThanOrEqual(5);
      expect(expired).toBe(2);
      expect(draft).toBe(1);
    });

    it('should have valid date ranges', () => {
      leases.forEach((l) => {
        const start = new Date(l.startDate);
        const end = new Date(l.endDate);
        expect(end.getTime()).toBeGreaterThan(start.getTime());
      });
    });
  });

  describe('communications.json', () => {
    let comms;
    beforeAll(() => { comms = loadJson('communications.json'); });

    it('should have sample communications', () => {
      expect(comms.length).toBeGreaterThanOrEqual(5);
    });

    it('should have Messenger communications', () => {
      const types = new Set(comms.map((c) => c.type));
      expect(types).toContain('fb_messenger');
      expect(types).toContain('sms');
    });

    it('should have both inbound and outbound', () => {
      const directions = new Set(comms.map((c) => c.direction));
      expect(directions).toContain('inbound');
      expect(directions).toContain('outbound');
    });

    it('should have French content', () => {
      comms.forEach((c) => {
        expect(c.content).toBeTruthy();
      });
    });
  });

  describe('cross-reference integrity', () => {
    let buildings, units, employees, leads, visits, leases, communications;

    beforeAll(() => {
      buildings = loadJson('buildings.json');
      units = loadJson('units.json');
      employees = loadJson('employees.json');
      leads = loadJson('leads.json');
      visits = loadJson('visits.json');
      leases = loadJson('leases.json');
      communications = loadJson('communications.json');
    });

    it('all unit building indices should be valid', () => {
      units.forEach((u) => {
        expect(u.buildingIndex).toBeLessThan(buildings.length);
      });
    });

    it('all visit indices should be valid', () => {
      visits.forEach((v) => {
        expect(v.unitIndex).toBeLessThan(units.length);
        expect(v.employeeIndex).toBeLessThan(employees.length);
        expect(v.leadIndex).toBeLessThan(leads.length);
      });
    });

    it('all lease unit indices should be valid', () => {
      leases.forEach((l) => {
        expect(l.unitIndex).toBeLessThan(units.length);
        if (l.leadIndex !== null) {
          expect(l.leadIndex).toBeLessThan(leads.length);
        }
      });
    });

    it('all communication indices should be valid', () => {
      communications.forEach((c) => {
        expect(c.employeeIndex).toBeLessThan(employees.length);
        expect(c.leadIndex).toBeLessThan(leads.length);
      });
    });
  });
});
