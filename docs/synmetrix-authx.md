# Synmetrix: Roles and User Model Documentation

**Disclaimer:**  
_This documentation is based on my current observations and usage of Synmetrix. It may not fully reflect the intended or final system behavior, and should be taken with a grain of salt. Further verification is recommended._

---

## Summary

Synmetrix uses a team-based model for user and permission management. Each user starts with a default team and can define roles and invite other users into their teams. There is no centralized admin role; instead, permissions are scoped per team. Roles like "Owner," "Admin," and "Member" exist, but the boundaries between them—especially Owner vs Admin—are not yet fully clear. User onboarding currently relies on manual signup without support for SSO or invite-based registration.

---
## Notes on Current Flow

- User onboarding is limited to **self-signup** through the standard registration flow.
- There is no invite-based registration mechanism.
- A **Team Owner** can invite an **existing Synmetrix user** to join their team as either:
  - **Admin**
  - **Member**
- The **Owner/Admin** distinction may need further clarification as the product evolves.


---

## Default User Flow

When a **new user** signs up or logs in:

1. **Gets a default "Team"** automatically created.
2. **Can create additional Teams** if desired.
3. **Onboards Data Sources** into any of their Teams.
4. **Defines "Roles"** within a Team.
5. **Invites other registered users** into the Team.
6. Assigns those users **roles** as part of the invite flow.

---

## Team Ownership & Roles

- Users can define **custom roles** at the **Team level**.
- There is a concept of a **"Team Owner"**:
  - The **Owner** is the user who created the team.
  - The Owner can invite, manage, and assign roles to others.
  - Ownership appears to be **scoped to Teams**, not globally.
- The distinction between **Team Owner** and **Team Admin** is currently **unclear**.

---

## Admin Visibility

- **No global admin** appears to exist by default:
  - Admin-like visibility (e.g., seeing all users or teams) is **not available out of the box**.
  - Users with elevated permissions (e.g., "admin" of a team) have visibility **only within that team**.
- The only way to gain broader control is to **design the role structure accordingly**, or **become the Owner of multiple Teams**.

---

