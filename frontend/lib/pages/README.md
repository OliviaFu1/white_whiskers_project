# Pages

Overview of every page in the app, grouped by folder.

---

## `app_shell.dart`
The root scaffold that wraps the entire authenticated app. Renders the top app bar (user avatar, pet selector, notifications bell) and the bottom navigation bar. Listens for notification taps and routes to the correct page. All three main tabs (Calendar, Journal, My Pet) are rendered here via `selectedTabNotifier`.

---

## auth/

| File | Description |
|---|---|
| `auth_gate.dart` | Entry point after launch. Checks for a stored token and routes the user to either the app shell or the login page. |
| `login_page.dart` | Email + password login form. Handles JWT token storage on success and navigates to `PostLoginGate`. |
| `register_page.dart` | New account registration form. Collects name, email, and password. |
| `post_login_gate.dart` | Runs after a successful login. Loads the user profile and pet list into global state, then navigates into the main app. |

---

## onboarding/

| File | Description |
|---|---|
| `onboarding_flow.dart` | Multi-step onboarding shown to new users after registration. Walks through app intro screens and creates the first pet. |
| `onboarding_widget.dart` | Reusable UI components used by the onboarding flow (illustrated step cards, progress indicators). |

---

## main_pages/

The three tabs accessible from the bottom navigation bar, plus supporting pages.

| File | Description |
|---|---|
| `calendar_page.dart` | Monthly calendar view. Shows pet events, vet appointments, and journal entries by date. |
| `journal_page.dart` | List of journal entries for the selected pet. Supports browsing past entries. |
| `add_journal_page.dart` | Form for creating or editing a journal entry. |
| `daily_checkin_page.dart` | Daily check-in form for logging how the pet is doing on a given day. |
| `day_details_page.dart` | Detail view for a single calendar day, showing all events and entries logged for that date. |
| `mypet_page.dart` | Main "My Pet" tab. Shows a swipeable carousel of pet cards, the latest wellness assessment scores, and quick-action shortcuts. |
| `pet_form_page.dart` | Form for creating or editing a pet profile (name, species, breed, birthdate, photo, etc.). |
| `pet_detail_page.dart` | Full detail view for a single pet, showing all stored information and edit options. |
| `manage_vet_page.dart` | Page for adding and managing vet contact information for a pet. |

---

## medication/

| File | Description |
|---|---|
| `medication_page.dart` | Day-by-day medication schedule. Shows which medications are due on the selected date with a pet chip row for switching between pets. Opened when a medication notification is tapped. |
| `pet_medications_page.dart` | Full medication list for a specific pet, grouped by status (active, paused, completed). Entry point from the My Pet quick actions. |
| `medication_detail_page.dart` | Detail view for a single medication. Shows schedule, prescription info, dosing history, and status controls (pause, complete, reactivate). |
| `medication_form_page.dart` | Form for adding or editing a medication. Covers drug name, dose, schedule type (fixed time, interval, weekly, as-needed), and prescription details. |
| `medication_log_page.dart` | History of all logged dose events for a medication. |
| `prescription_supply_page.dart` | Tracks remaining supply for a prescription and shows expected run-out date. |

---

## assessment/

| File | Description |
|---|---|
| `assessment_page.dart` | Multi-step wellness assessment questionnaire. Scores the pet across categories like appetite, mobility, and state of mind. |
| `assessment_results.dart` | Displays the heart score and condition score from a completed assessment, along with a radar chart breakdown. |
| `assessment_history.dart` | List of all past assessments for a pet with scores and dates. |
| `assessment_radar_chart.dart` | Reusable radar/spider chart widget used in assessment results. |
| `assessment_components.dart` | Shared UI components used across assessment pages (scale sliders, score badges, etc.). |
| `share_assessment_page.dart` | Allows the user to share assessment results (e.g. with a vet). |

---

## profile/

| File | Description |
|---|---|
| `profile_page.dart` | User profile page. Shows account info and links to all profile sub-pages. |
| `notifications_settings_page.dart` | Notification preferences. Master on/off switch plus per-category toggles for dose reminders, refill alerts, and birthday reminders. |
| `privacy_page.dart` | Privacy settings and data management options. |
| `manage_family_members_page.dart` | Manage who has access to a pet's profile. Invite or remove family members. |
| `help_support_page.dart` | Help & Support page with an FAQ accordion and contact information. |
| `about_page.dart` | About the app — version info, legal links (terms, privacy, licenses), and credits. |

---

## notifications_page.dart
Full-screen notification inbox. Lists all backend notifications (dose logs, refill alerts, etc.) with read/unread state.

---

## repositories/

Data-access helpers that sit between pages and API services.

| File | Description |
|---|---|
| `pet_repository.dart` | Fetches and maps the pet list from the API into `Pet` model objects. |
| `notification_repository.dart` | Fetches and maps the notification list from the API into `AppNotification` model objects. |
