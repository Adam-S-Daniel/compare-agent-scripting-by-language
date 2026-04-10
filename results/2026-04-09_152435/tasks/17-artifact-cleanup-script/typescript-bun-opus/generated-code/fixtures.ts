// fixtures.ts — Test fixture data for artifact cleanup tests
// Reference date: 2026-04-10T00:00:00Z
//
// Artifact ages from reference date:
//   deploy-bundle-1:  54 days (Feb 15)
//   build-artifact-1: 40 days (Mar 1)
//   test-results-1:   31 days (Mar 10)
//   build-artifact-2: 26 days (Mar 15)
//   build-artifact-3:  9 days (Apr 1)
//   test-results-2:    5 days (Apr 5)
//   deploy-bundle-2:   2 days (Apr 8)
//
// Total size: 13,750,000 bytes

import type { Artifact } from "./types";

export const REFERENCE_DATE = new Date("2026-04-10T00:00:00Z");

export const TEST_ARTIFACTS: Artifact[] = [
  {
    name: "build-artifact-1",
    sizeBytes: 1_000_000,
    createdAt: "2026-03-01T00:00:00Z",
    workflowRunId: "workflow-a",
  },
  {
    name: "build-artifact-2",
    sizeBytes: 2_000_000,
    createdAt: "2026-03-15T00:00:00Z",
    workflowRunId: "workflow-a",
  },
  {
    name: "build-artifact-3",
    sizeBytes: 1_500_000,
    createdAt: "2026-04-01T00:00:00Z",
    workflowRunId: "workflow-a",
  },
  {
    name: "test-results-1",
    sizeBytes: 500_000,
    createdAt: "2026-03-10T00:00:00Z",
    workflowRunId: "workflow-b",
  },
  {
    name: "test-results-2",
    sizeBytes: 750_000,
    createdAt: "2026-04-05T00:00:00Z",
    workflowRunId: "workflow-b",
  },
  {
    name: "deploy-bundle-1",
    sizeBytes: 5_000_000,
    createdAt: "2026-02-15T00:00:00Z",
    workflowRunId: "workflow-c",
  },
  {
    name: "deploy-bundle-2",
    sizeBytes: 3_000_000,
    createdAt: "2026-04-08T00:00:00Z",
    workflowRunId: "workflow-c",
  },
];
