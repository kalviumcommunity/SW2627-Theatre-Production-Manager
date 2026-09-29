# Problem Statement

## Original Problem Statement

> "A regional theatre group manages auditions, rehearsal schedules, and cast assignments across several simultaneous productions, but coordination through group chats becomes unmanageable once multiple productions run in parallel. Cast members miss schedule changes, venues get double-booked, and directors have no consolidated view of commitments."

## Context

A regional theatre group produces more than one show at a time. Each production needs auditions, a cast, rehearsals, and a venue. Directors, cast members, and venues are shared or overlapping across these productions, so a decision made for one production can affect another.

## Current Situation

Coordination currently happens through group chats. This is workable for a single production. With several productions running in parallel, information about auditions, rehearsal times, and cast assignments is spread across many conversations, and there is no single authoritative record of what is scheduled.

## Core Problems

| # | Problem | Description |
|---|---|---|
| 1 | Missed schedule changes | Cast members do not reliably see updates that are posted among other messages. |
| 2 | Venue double-booking | The same venue is committed to more than one production at overlapping times. |
| 3 | No consolidated director view | Directors cannot see all commitments across productions in one place. |

## Impact of the Problems

- Cast members may miss or arrive late to a rehearsal because a change went unnoticed.
- Double-booked venues force last-minute rescheduling or relocation, disrupting the affected productions.
- Directors have to piece together commitments manually, which makes conflicts harder to notice early.
- Coordination effort grows with each additional production.

## Key Stakeholders

| Stakeholder | Interest |
|---|---|
| Directors | Need an accurate, combined view of commitments and a reliable way to communicate schedule changes. |
| Cast members | Need to know current audition and rehearsal details without searching through chats. |
| Theatre group management | Need productions to run without avoidable scheduling conflicts. |

## Why a Centralized Flutter and Firebase Application Is Appropriate

- **One shared record.** Schedules, cast assignments, and venue usage kept in one place remove the need to reconstruct information from chat history.
- **Conflict checking.** Structured venue and time data allows overlaps to be detected before they become double-bookings, which chat messages cannot do.
- **Targeted updates.** Changes recorded in the system can be delivered to the specific people affected.
- **Cross-platform access.** Flutter allows a single Dart codebase for the devices cast members and directors are likely to use.
- **Managed services.** Firebase Authentication, Cloud Firestore, and Firebase Cloud Messaging cover sign-in, data storage, and notifications without a separately maintained backend server, which suits the scope and resources of a student project.

## Problem Boundaries

**Within the problem:**

- Coordinating auditions, rehearsal schedules, and cast assignments across simultaneous productions.
- Preventing venue double-booking.
- Making schedule changes visible to affected cast members.
- Giving directors a consolidated view of commitments.

**Outside the problem:**

- Aspects of theatre production not mentioned in the problem statement, such as ticketing, budgeting, or creative content.
- Replacing all informal communication between group members.

Detailed scope decisions are recorded in [problem-analysis.md](problem-analysis.md).