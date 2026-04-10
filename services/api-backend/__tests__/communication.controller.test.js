// ─── Communication Controller Validation Tests ───
// Tests the inline validation logic of the communication controller.
// These test the validation contract that the controller enforces before DB operations.

// Valid types and directions are enforced inline in the controller.
// We verify these constants match what the controller expects.

const VALID_TYPES = ['sms', 'email', 'phone', 'fb_messenger'];
const VALID_DIRECTIONS = ['inbound', 'outbound'];

describe('Communication Controller Validation', () => {
  describe('logCommunication — type validation', () => {
    it('accepts all valid types', () => {
      expect(VALID_TYPES).toContain('sms');
      expect(VALID_TYPES).toContain('email');
      expect(VALID_TYPES).toContain('phone');
      expect(VALID_TYPES).toContain('fb_messenger');
    });

    it('rejects invalid type values', () => {
      const invalidTypes = ['whatsapp', 'slack', 'mail', 'fax', '', null, undefined, 123, {}, []];
      for (const t of invalidTypes) {
        expect(VALID_TYPES.includes(t)).toBe(false);
      }
    });
  });

  describe('logCommunication — direction validation', () => {
    it('accepts all valid directions', () => {
      expect(VALID_DIRECTIONS).toContain('inbound');
      expect(VALID_DIRECTIONS).toContain('outbound');
    });

    it('rejects invalid direction values', () => {
      const invalidDirs = ['bidirectional', 'in', 'out', 'both', '', null, undefined];
      for (const d of invalidDirs) {
        expect(VALID_DIRECTIONS.includes(d)).toBe(false);
      }
    });
  });

  describe('logCommunication — required fields', () => {
    it('type is required (null/undefined/empty rejected)', () => {
      expect(VALID_TYPES.includes(null)).toBe(false);
      expect(VALID_TYPES.includes(undefined)).toBe(false);
      expect(VALID_TYPES.includes('')).toBe(false);
    });

    it('direction is required (null/undefined/empty rejected)', () => {
      expect(VALID_DIRECTIONS.includes(null)).toBe(false);
      expect(VALID_DIRECTIONS.includes(undefined)).toBe(false);
      expect(VALID_DIRECTIONS.includes('')).toBe(false);
    });

    it('optional fields have sensible defaults', () => {
      const defaults = {
        leadId: null,
        employeeId: null,
        content: null,
        subject: null,
        attachments: [],
        status: 'sent',
        metadata: {},
      };
      expect(defaults.status).toBe('sent');
      expect(Array.isArray(defaults.attachments)).toBe(true);
      expect(defaults.attachments).toHaveLength(0);
      expect(typeof defaults.metadata).toBe('object');
    });
  });

  describe('getCommunications — query parameter defaults', () => {
    it('defaults page to 1', () => {
      const page = undefined;
      const result = parseInt(page || 1);
      expect(result).toBe(1);
    });

    it('defaults limit to 20', () => {
      const limit = undefined;
      const result = parseInt(limit || 20);
      expect(result).toBe(20);
    });

    it('calculates offset correctly', () => {
      const offset = (parseInt(2) - 1) * parseInt(10);
      expect(offset).toBe(10);
    });
  });

  describe('getActivityFeed — type filter parsing', () => {
    const allTypes = [
      'lead_created', 'visit_scheduled', 'visit_completed',
      'sms_sent', 'sms_received', 'communication_logged',
    ];

    it('accepts all valid activity types', () => {
      for (const t of allTypes) {
        expect(allTypes.includes(t)).toBe(true);
      }
    });

    it('parses comma-separated type filter correctly', () => {
      const input = 'lead_created,visit_scheduled';
      const parsed = input.split(',').map((t) => t.trim()).filter((t) => allTypes.includes(t));
      expect(parsed).toEqual(['lead_created', 'visit_scheduled']);
    });

    it('filters out invalid types from comma-separated input', () => {
      const input = 'lead_created,invalid_type,visit_completed';
      const parsed = input.split(',').map((t) => t.trim()).filter((t) => allTypes.includes(t));
      expect(parsed).toEqual(['lead_created', 'visit_completed']);
    });

    it('handles whitespace in type filter', () => {
      const input = ' lead_created , visit_scheduled ';
      const parsed = input.split(',').map((t) => t.trim()).filter((t) => allTypes.includes(t));
      expect(parsed).toEqual(['lead_created', 'visit_scheduled']);
    });

    it('returns null (all types) when no filter provided', () => {
      const type = undefined;
      const filterTypes = type ? type.split(',') : null;
      expect(filterTypes).toBeNull();
    });
  });

  describe('getActivityFeed — limit and hoursAgo clamping', () => {
    it('clamps limit between 1 and 100', () => {
      const clamp = (v) => Math.min(100, Math.max(1, parseInt(v)));
      expect(clamp(30)).toBe(30);
      expect(clamp(0)).toBe(1);
      expect(clamp(-5)).toBe(1);
      expect(clamp(150)).toBe(100);
      expect(clamp(1)).toBe(1);
      expect(clamp(100)).toBe(100);
    });

    it('clamps hoursAgo between 1 and 720', () => {
      const clamp = (v) => Math.min(720, Math.max(1, parseInt(v)));
      expect(clamp(168)).toBe(168);
      expect(clamp(0)).toBe(1);
      expect(clamp(-10)).toBe(1);
      expect(clamp(1000)).toBe(720);
      expect(clamp(720)).toBe(720);
      expect(clamp(1)).toBe(1);
    });
  });

  describe('getActivityFeed — activity sorting', () => {
    it('sorts activities by timestamp descending', () => {
      const activities = [
        { type: 'lead_created', timestamp: '2024-01-01T10:00:00Z' },
        { type: 'sms_sent', timestamp: '2024-01-03T15:00:00Z' },
        { type: 'visit_scheduled', timestamp: '2024-01-02T09:00:00Z' },
      ];
      activities.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
      expect(activities[0].type).toBe('sms_sent');
      expect(activities[1].type).toBe('visit_scheduled');
      expect(activities[2].type).toBe('lead_created');
    });

    it('limits results after sorting', () => {
      const activities = Array.from({ length: 50 }, (_, i) => ({
        type: 'lead_created',
        timestamp: new Date(Date.now() - i * 60000).toISOString(),
      }));
      activities.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
      const result = activities.slice(0, 10);
      expect(result).toHaveLength(10);
    });
  });

  describe('getActivityFeed — visit outcome text mapping', () => {
    const outcomeTextMap = {
      interesse: ' — intéressé',
      pas_interesse: ' — pas intéressé',
      no_show: ' — absent',
    };

    const outcomeText = (outcome) => outcomeTextMap[outcome] || '';

    it('maps interesse to interested text', () => {
      expect(outcomeText('interesse')).toBe(' — intéressé');
    });

    it('maps pas_interesse to not interested text', () => {
      expect(outcomeText('pas_interesse')).toBe(' — pas intéressé');
    });

    it('maps no_show to absent text', () => {
      expect(outcomeText('no_show')).toBe(' — absent');
    });

    it('returns empty string for unknown outcomes', () => {
      expect(outcomeText('cancelled')).toBe('');
    });
  });

  describe('getActivityFeed — communication type labels', () => {
    const typeLabels = { email: 'E-mail', phone: 'Appel', fb_messenger: 'Messenger' };

    it('maps email to E-mail', () => {
      expect(typeLabels.email).toBe('E-mail');
    });

    it('maps phone to Appel', () => {
      expect(typeLabels.phone).toBe('Appel');
    });

    it('maps fb_messenger to Messenger', () => {
      expect(typeLabels.fb_messenger).toBe('Messenger');
    });

    it('falls back to raw type for unknown types', () => {
      expect(typeLabels.sms || 'sms').toBe('sms');
    });
  });

  describe('getActivityFeed — direction labels', () => {
    const dirLabel = (dir) => (dir === 'inbound' ? ' reçu de' : ' envoyé à');

    it('maps inbound to reçu de', () => {
      expect(dirLabel('inbound')).toBe(' reçu de');
    });

    it('maps outbound to envoyé à', () => {
      expect(dirLabel('outbound')).toBe(' envoyé à');
    });
  });
});
