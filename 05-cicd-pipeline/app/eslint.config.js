const js = require("@eslint/js");

module.exports = [
  js.configs.recommended,

  {
    files: ["**/*.js"],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "commonjs",
      globals: {
        process: "readonly",
        console: "readonly",
        fetch: "readonly",
      },
    },
    rules: {
    },
  },
];
