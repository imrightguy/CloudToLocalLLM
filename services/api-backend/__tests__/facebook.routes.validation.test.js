const validate = require('../src/middleware/validate');
const { facebookWebhookSchemas } = require('../src/config/validation-schemas');
const facebookRouter = require('../src/routes/facebook.routes');

function mockReqRes(body = {}, query = {}, params = {}) {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  const next = jest.fn();
  return { req: { body, query, params }, res, next };
}

describe('Facebook webhook validation contract', () => {
  it('protects POST / with validation middleware before the controller', () => {
    const postRoute = facebookRouter.stack.find((layer) => layer.route?.path === '/' && layer.route.methods.post);

    expect(postRoute).toBeDefined();
    expect(postRoute.route.stack.map((layer) => layer.name)).toEqual(['<anonymous>', '<anonymous>']);
  });

  it('preserves lead ad change payloads supported by the webhook controller', () => {
    const leadValue = {
      leadgen_id: '123456',
      field_data: [{ name: 'full_name', values: ['Jean Tremblay'] }],
      ad_id: 'ad_001',
      page_id: 'page_001',
    };
    const { req, res, next } = mockReqRes({
      object: 'page',
      entry: [{
        id: 'entry_1',
        changes: [{ field: 'leadgen_id', value: leadValue }],
      }],
    });

    validate(facebookWebhookSchemas.webhook)(req, res, next);

    expect(res.status).not.toHaveBeenCalled();
    expect(next).toHaveBeenCalledWith();
    expect(req.body.entry[0].changes).toEqual([{ field: 'leadgen_id', value: leadValue }]);
  });

  it('preserves mixed messenger + lead ad entries so marketplace messages and lead ads can share a batch', () => {
    const { req, res, next } = mockReqRes({
      object: 'page',
      entry: [{
        id: 'entry_1',
        messaging: [{ sender: { id: '222' }, message: { text: 'Bonjour' } }],
        changes: [{ field: 'leadgen_id', value: { leadgen_id: 'L1', field_data: [] } }],
      }],
    });

    validate(facebookWebhookSchemas.webhook)(req, res, next);

    expect(res.status).not.toHaveBeenCalled();
    expect(next).toHaveBeenCalledWith();
    expect(req.body.entry[0]).toEqual({
      id: 'entry_1',
      messaging: [{ sender: { id: '222' }, message: { text: 'Bonjour' } }],
      changes: [{ field: 'leadgen_id', value: { leadgen_id: 'L1', field_data: [] } }],
    });
  });
});
