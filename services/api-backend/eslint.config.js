import js from '@eslint/js';
import globals from 'globals';

export default [
  // Apply to all JavaScript files
  {
    files: ['**/*.js'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
      globals: {
        ...globals.node,
        ...globals.es2022,
      },
    },
    rules: {
      ...js.configs.recommended.rules,
      'no-console': 'off',
      'no-debugger': 'warn',
      semi: ['error', 'always'],
      'no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
      'no-undef': 'error',
      eqeqeq: 'error',
      curly: 'error',
      'brace-style': ['error', '1tbs'],
      'object-curly-spacing': ['error', 'always'],
      'array-bracket-spacing': ['error', 'never'],
      'comma-spacing': ['error', { before: false, after: true }],
      'key-spacing': ['error', { beforeColon: false, afterColon: true }],
      'space-before-blocks': 'error',
      // Disable style rules that conflict with Prettier or cause CI failures
      quotes: 'off',
      'comma-dangle': 'off',
      indent: 'off',
      'space-before-function-paren': 'off',
      'no-trailing-spaces': 'error',
      'eol-last': 'error',
    },
  },
  // Test files configuration
  {
    files: ['tests/**/*.js', '**/*.test.js', '**/*.spec.js'],
    languageOptions: {
      globals: {
        ...globals.node,
        ...globals.es2022,
        ...globals.jest,
      },
    },
    rules: {
      // Allow console in tests for debugging
      'no-console': 'off',
    },
  },
  // Jest setup file configuration
  {
    files: ['jest.setup.js', '**/jest.setup.js'],
    languageOptions: {
      globals: {
        ...globals.node,
        ...globals.es2022,
        ...globals.jest,
        require: 'readonly',
      },
    },
    rules: {
      // Allow using Jest globals and conditional require in setup
      'no-undef': 'off',
    },
  },
];
