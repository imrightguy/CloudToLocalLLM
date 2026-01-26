# WebSocket Module Installation Guide

## Package Dependencies

The WebSocket module requires the `ws` package to be installed.

### Install Dependencies

```bash
cd services/streaming-proxy
npm install ws @types/ws
```

### Update package.json

Add the following to `dependencies`:

```json
{
  "dependencies": {
    "ws": "^8.14.0",
    "@types/ws": "^8.5.8"
  }
}
```

## TypeScript Configuration

Ensure `tsconfig.json` includes:

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ES2020",
    "moduleResolution": "node",
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "skipLibCheck": true
  }
}
```

## Build Configuration

### For Development

```bash
npm run dev
```

### For Production

```bash
npm run build
npm start
```

## Verification

After installation, verify the module compiles without errors:

```bash
npx tsc --noEmit
```

Expected output: No errors

## Integration Checklist

- [ ] Install `ws` and `@types/ws` packages
- [ ] Update package.json with dependencies
- [ ] Configure TypeScript (tsconfig.json)
- [ ] Verify compilation with `npx tsc --noEmit`
- [ ] Run tests (when available)
- [ ] Update server entry point to use WebSocketHandlerImpl
- [ ] Configure environment variables
- [ ] Test WebSocket connections
- [ ] Monitor logs for errors
- [ ] Check health endpoints

## Next Steps

1. Install dependencies: `npm install ws @types/ws`
2. Follow [GETTING_STARTED.md](./GETTING_STARTED.md) for setup
3. Read [QUICK_START.md](./QUICK_START.md) for quick reference
4. Review [README.md](./README.md) for detailed documentation

## Troubleshooting

### Error: Cannot find module 'ws'

**Solution**: Install the ws package:

```bash
npm install ws @types/ws
```

### TypeScript Compilation Errors

**Solution**: Ensure TypeScript is configured correctly:

```bash
npm install -D typescript @types/node
npx tsc --init
```

### Module Resolution Issues

**Solution**: Update tsconfig.json:

```json
{
  "compilerOptions": {
    "moduleResolution": "node"
  }
}
```

## Support

For installation issues, check:

1. Node.js version (18+)
2. npm version (8+)
3. Package lock file integrity
4. Network connectivity for package downloads
