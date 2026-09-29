# Theatre Production Manager

Repository: `SW2627-Theatre-Production-Manager`
Simulated Work Sprint 2 | Semester 3 | JECRC | Team 02, Squad 124

## Description

Theatre Production Manager is a planned Flutter and Firebase application for a regional theatre group that runs several productions at the same time. It is intended to replace group-chat coordination of auditions, rehearsals, and cast assignments with one shared system.

> Status note: this project is in the documentation stage. All modules and technologies listed here are planned. No feature has been implemented.

## Problem Summary

A regional theatre group manages auditions, rehearsal schedules, and cast assignments across several simultaneous productions. Coordination through group chats becomes unmanageable once multiple productions run in parallel. The full problem statement is in [docs/problem-statement.md](docs/problem-statement.md).

## Project Objective

Define and, in later stages, build a centralized application that lets the theatre group:

- keep schedule information in one place so cast members are not left with outdated details,
- prevent a venue from being booked for overlapping productions, and
- give directors a single view of commitments across all productions.

## Core Problems Being Addressed

| # | Problem |
|---|---|
| 1 | Cast members miss schedule changes. |
| 2 | Venues get double-booked. |
| 3 | Directors have no consolidated view of commitments. |

## Planned Modules

| Module | Status |
|---|---|
| Production Management | Planned |
| Audition Management | Planned |
| Cast Management | Planned |
| Rehearsal Scheduling | Planned |
| Venue Management | Planned |
| Schedule / Commitment Management | Planned |
| Notifications | Planned |

## Technology Stack

These are the planned technologies for the project.

| Layer | Technology |
|---|---|
| Application | Flutter |
| Language | Dart |
| Authentication | Firebase Authentication |
| Database | Cloud Firestore |
| Notifications | Firebase Cloud Messaging |

No separate backend server is planned. Other Firebase services will be added only if a requirement clearly justifies them.

## Development Workflow

The project follows a branch-based Git workflow.

1. Create a branch for each task.
2. Complete the assigned work.
3. Commit the changes with a clear commit message.
4. Push the branch to GitHub.
5. Create a Pull Request to `main`.
6. A teammate reviews the Pull Request.
7. Approved changes are merged into `main`.

## High-Level Architecture

```text
User
  |
  v
Flutter Application
  |
  +--> Firebase Authentication
  +--> Cloud Firestore
  +--> Firebase Cloud Messaging
```

The Flutter application communicates directly with Firebase services. The intended repository layout is described in [docs/project-structure.md](docs/project-structure.md).

## Team

| Member | Role in this stage |
|---|---|
| Vidit | Repository foundation, README, project structure, initial documentation |
| Himesh | Problem analysis |
| Ayushman | Team member (no contribution in this stage) |

Team 02, Squad 124, JECRC campus.

## Current Project Status

| Area | Status |
|---|---|
| Problem definition | Documented |
| Problem analysis | Documented |
| Repository structure | Planned (documented only) |
| Flutter project setup | Not started |
| Firebase project setup | Not started |

## Development Status

No application code has been written. The repository currently contains documentation only. Every module and feature in this repository is planned, not implemented. This section will be updated as work begins.

## Documentation

| Document | Description |
|---|---|
| [docs/problem-statement.md](docs/problem-statement.md) | Original problem statement, context, impact, stakeholders, and boundaries |
| [docs/problem-analysis.md](docs/problem-analysis.md) | Workflow analysis, requirements, constraints, MVP scope, and success criteria |
| [docs/project-structure.md](docs/project-structure.md) | Planned Flutter and Firebase repository structure |

## Basic Development Workflow

Not every team member works every day. Each contribution follows the same steps:

1. Create a personal branch from `main`.
2. Make and commit changes on that branch.
3. Push the branch to the remote repository.
4. Open a Pull Request into `main`.
5. Another team member reviews the Pull Request.
6. After approval, the Pull Request is merged into `main`.

Suggested branch names: `docs/<topic>` for documentation and `feature/<topic>` for later feature work. Direct commits to `main` should be avoided.