# Theatre Production Manager — App Requirements

## 1. Purpose

The Theatre Production Manager is a Flutter application designed to help a regional theatre group manage multiple productions, auditions, cast assignments, rehearsals, venues, and schedules from one centralized system.

The application reduces problems caused by managing theatre activities through multiple group chats.

---

## 2. Main Problems Addressed

The application addresses the following problems:

- Cast members miss schedule changes.
- Multiple productions can run at the same time.
- Venues can be double-booked.
- Directors do not have a consolidated view of their productions.
- Cast members may have conflicting rehearsal commitments.
- Important audition and rehearsal information gets lost in group chats.

---

## 3. User Roles

### Director

The director can:

- Create and manage productions.
- Create auditions.
- View audition participants.
- Assign cast members to roles.
- Schedule rehearsals.
- Select venues.
- View production schedules.
- Detect schedule and venue conflicts.
- View an overall dashboard.

### Cast Member

A cast member can:

- View available productions.
- View auditions.
- Participate in auditions.
- View assigned roles.
- View rehearsal schedules.
- View upcoming commitments.
- Receive schedule updates and notifications.

### Coordinator

A coordinator can:

- Manage venues.
- View production schedules.
- Assist with rehearsal scheduling.
- Monitor venue conflicts.
- View production and schedule information.

---

# 4. Application Screens

## 4.1 Login Screen

Purpose:

Allows users to securely log into the application.

Main elements:

- Email field
- Password field
- Login button
- Registration option
- Error message for invalid credentials

Authentication will use Firebase Authentication.

---

## 4.2 Registration Screen

Purpose:

Allows a new user to create an account.

Main elements:

- Name
- Email
- Password
- Confirm password
- Role selection
- Register button

Authentication will use Firebase Authentication.

---

## 4.3 Dashboard

Purpose:

Provides users with a quick overview of their theatre activities.

Director dashboard may display:

- Total productions
- Upcoming auditions
- Upcoming rehearsals
- Active productions
- Schedule conflicts
- Venue conflicts

Cast member dashboard may display:

- Assigned productions
- Upcoming rehearsals
- Upcoming auditions
- Today's commitments
- Recent schedule updates

---

## 4.4 Productions Screen

Purpose:

Displays all productions managed by the theatre group.

Information displayed:

- Production name
- Description
- Status
- Director
- Start date
- End date

Director actions:

- Create production
- Edit production
- View production details

---

## 4.5 Production Details Screen

Purpose:

Displays complete information about one production.

Information:

- Production name
- Description
- Director
- Cast members
- Auditions
- Rehearsals
- Venue
- Schedule

---

## 4.6 Auditions Screen

Purpose:

Allows directors to create and manage auditions.

Information:

- Production
- Audition date
- Audition time
- Venue
- Required roles
- Description
- Status

Director actions:

- Create audition
- View participants
- Assign selected cast members

Cast member actions:

- View available auditions
- Apply/participate in an audition

---

## 4.7 Cast Screen

Purpose:

Displays cast members and their assigned roles.

Information:

- Cast member name
- Production
- Assigned role
- Contact information
- Availability

Director actions:

- Assign actor to role
- Change role
- Remove assignment

---

## 4.8 Rehearsals Screen

Purpose:

Allows rehearsal sessions to be created and managed.

Information:

- Production
- Date
- Start time
- End time
- Venue
- Participants
- Notes

Director/coordinator actions:

- Create rehearsal
- Edit rehearsal
- Cancel rehearsal

Cast members can:

- View upcoming rehearsals
- View rehearsal details

---

## 4.9 Venues Screen

Purpose:

Manages theatre venues used for auditions, rehearsals, and productions.

Information:

- Venue name
- Location
- Capacity
- Availability
- Current booking

The system should prevent or identify overlapping venue bookings.

---

## 4.10 Schedule / Calendar Screen

Purpose:

Provides a consolidated view of theatre commitments.

The calendar can display:

- Auditions
- Rehearsals
- Productions
- Venue bookings

Users can select an event to view its details.

The schedule should help users identify overlapping commitments.

---

## 4.11 Notifications

Purpose:

Keeps users informed about important changes.

Possible notifications:

- Rehearsal scheduled
- Rehearsal time changed
- Venue changed
- Audition reminder
- Cast assignment
- Schedule conflict
- Production update

Firebase Cloud Messaging will be used for push notifications.

---

# 5. Navigation Flow

The basic application flow is:

```text
                    ┌──────────────┐
                    │ Login/Register│
                    └──────┬───────┘
                           │
                           ▼
                    ┌──────────────┐
                    │   Dashboard  │
                    └──────┬───────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
  Productions          Auditions           Cast
        │                  │                  │
        ▼                  ▼                  ▼
Production Details   Audition Details    Role Details
        │
        ├──────────────► Rehearsals
        │
        ├──────────────► Venues
        │
        └──────────────► Schedule / Calendar

                    ┌──────────────┐
                    │ Notifications│
                    └──────────────┘