// Mock commit logs for testing
export const testFixtures = {
  patchOnly: `fix: resolve null pointer exception
fix(db): optimize query performance`,

  minorWithFix: `feat: add user authentication
feat(api): add oauth support
fix: correct error message`,

  majorWithBreaking: `feat!: redesign API contracts
feat(auth): add multi-factor authentication
fix: resolve session timeout issue`,

  mixedWithScopes: `feat(frontend): implement dark mode
fix(backend): fix memory leak
feat(docs): add API documentation
chore: update dependencies`,

  empty: "",

  singleFeat: "feat: add simple feature",

  multipleBreaking: `feat(core)!: rewrite core engine
fix(api)!: breaking API change
feat: add new feature`,
};

export const versionFixtures = {
  valid: ["1.0.0", "2.5.1", "0.0.1", "10.20.30"],
  withV: ["v1.0.0", "v2.5.1"],
  invalid: ["1.0", "1.0.0.0", "abc.def.ghi", "not-a-version"],
};

export const packageJsonFixtures = {
  simple: {
    name: "test-project",
    version: "1.0.0",
  },
  withDeps: {
    name: "test-project",
    version: "2.1.0",
    dependencies: {
      express: "^4.18.0",
    },
  },
};

export const expectedOutputs = {
  patchBump: {
    from: "1.0.0",
    to: "1.0.1",
    type: "patch",
  },
  minorBump: {
    from: "1.0.0",
    to: "1.1.0",
    type: "minor",
  },
  majorBump: {
    from: "1.0.0",
    to: "2.0.0",
    type: "major",
  },
};
