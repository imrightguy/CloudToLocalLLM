import js from '@eslint/js';
import globals from 'globals';

export default [
  {
    files: ['**/*.js'],
    ignores: ['scripts/**'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'script',
      globals: {
        ...globals.node,
        ...globals.es2022,
      },
    },
    rules: {
      ...js.configs.recommended.rules,
      'no-console': 'off',
      'no-debugger': 'warn',
      'no-unused-vars': ['warn', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
      eqeqeq: 'warn',
      curly: 'warn',
      'no-underscore-dangle': 'off',
      'comma-dangle': ['error', 'always-multiline'],
      'max-len': ['warn', { code: 120, ignoreStrings: true, ignoreTemplateLiterals: true }],
      'no-restricted-syntax': 'off',
      'no-await-in-loop': 'off',
      'no-continue': 'off',
      'no-param-reassign': 'off',
      'global-require': 'off',
      'prefer-destructuring': 'off',
      'quote-props': ['error', 'as-needed', { keywords: false, unnecessary: true, numbers: false }],
      radix: 'off',
      'no-use-before-define': ['error', { functions: false, classes: true, variables: true }],
      'consistent-return': 'off',
      'no-trailing-spaces': 'error',
      'eol-last': 'error',
    },
  },
  {
    files: ['__tests__/**/*.js', 'jest.setup.js'],
    languageOptions: {
      globals: {
        ...globals.node,
        ...globals.es2022,
        ...globals.jest,
      },
    },
  },
  {
    files: ['scripts/**/*.js'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'script',
      globals: {
        ...globals.node,
      },
    },
    rules: {
      'no-console': 'off',
    },
  },
];
