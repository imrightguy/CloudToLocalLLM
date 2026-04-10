module.exports = {
  root: true,
  env: {
    node: true,
    es2021: true,
    jest: true,
  },
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module',
  },
  extends: ['eslint:recommended', 'prettier'],
  plugins: ['prettier'],
  rules: {
    'prettier/prettier': 'error',
  },
  overrides: [
    {
      files: ['web/**/*.js'],
      env: {
        browser: true,
        serviceworker: true,
      },
      rules: {
        'no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
      },
    },
    {
      files: ['test/k6/**/*.js'],
      globals: {
        __ENV: 'readonly',
      },
    },
    {
      files: ['test/**/*.js', 'test/**/*.test.js', 'scripts/**/*.js'],
      env: {
        jest: true,
      },
      globals: {
        fail: 'readonly',
      },
      rules: {
        'no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
        'no-redeclare': 'off',
      },
    },
  ],
  ignorePatterns: ['services/', 'backend/', 'k8s/', 'docker/'],
};
