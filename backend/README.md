# Backend

Django REST Framework API. Organised as a standard Django project with one app per domain.

All endpoints require JWT authentication unless noted. Tokens are obtained at
`POST /api/auth/token/` and refreshed at `POST /api/auth/token/refresh/`.

---

## config/

Project-level configuration.

| File | Description |
|---|---|
| `settings.py` | Main Django settings. Reads secrets and DB config from environment variables. Configures JWT lifetimes, SendGrid email, and static/media file paths. |
| `urls.py` | Root URL router. Mounts all app URL configs under `/api/` and serves media files in development. |
| `wsgi.py` | WSGI entry point for production servers (gunicorn). |
| `asgi.py` | ASGI entry point (for future async/WebSocket support). |

---

## accounts/

User account management.

| File | Description |
|---|---|
| `models.py` | Custom `User` model (extends `AbstractBaseUser`). Stores name, email, profile photo, and primary vet/clinic contact info. Also defines `UserSpecialist` for saving additional vet contacts. |
| `views.py` | `RegisterView` — public endpoint to create a new account. `MeView` — retrieve, update, or delete the authenticated user's own profile. `ChangeEmailView` / `ChangePasswordView` — dedicated patch endpoints for credential changes. `PhotoUploadView` — multipart upload to set or remove the profile photo. `SpecialistListCreateView` / `SpecialistDetailView` — CRUD for saved vet specialists. `ShareRecipientsView` — returns a combined list of the primary vet and all specialists for use in the assessment share flow. |
| `serializers.py` | Serializers for registration, public profile read, profile update, email/password change, and specialist records. |
| `urls.py` | URL patterns for all account endpoints under `/api/accounts/`. |

---

## pets/

Pet profiles and multi-user pet access.

| File | Description |
|---|---|
| `models.py` | `Pet` model with name, species, breed, birthdate, sex, photo, and date of death. `PetUser` join model linking users to pets with a role (`owner` or `member`). `PetInvite` model for invite-by-code family sharing. |
| `views.py` | `PetListCreateView` — list all pets for the user, create a new pet (automatically assigns owner role). `PetDetailView` — retrieve, update, or delete a single pet (owner-only for write). Also contains `_sync_medications_for_death_change` which auto-completes or reverts medications when a pet's `date_of_death` is set or cleared. `PetPhotoView` — multipart patch to upload a pet's profile photo. |
| `serializers.py` | Serializers for pet read/create and all invite/family-sharing operations. |
| `urls.py` | URL patterns for pet endpoints under `/api/pets/`. |

---

## medications/

Medication tracking, scheduling, prescriptions, and dose notifications.

| File | Description |
|---|---|
| `models.py` | `Medication` — core record with drug name, dose, status (`active` / `paused` / `completed`), and schedule info. `MedicationSchedule` — one or more schedules per medication (`fixed_times`, `interval`, `weekly`, `as_needed`). `MedicationPrescription` — tracks supply quantity, expiration date, and `last_dose_logged_at` as a rolling cursor for dose calculations. `MedicationLog` — audit trail of status changes and dose events. |
| `views.py` | `MedicationViewSet` — full CRUD for medications. `partial_update` logs status changes to `MedicationLog` and resets the prescription cursor when a medication is reactivated. Custom action `process_due_doses` — calculates how many doses have elapsed since the last check, deducts supply, and creates backend notifications for due doses and refill alerts. `_count_elapsed_doses` helper handles `fixed_times`, `interval`, and `weekly` schedule types with timezone-aware arithmetic. |
| `serializers.py` | Serializers for medication read/create (with nested schedules and prescriptions) and log entries. |
| `urls.py` | URL patterns under `/api/medications/`. |

---

## notifications/

In-app notification inbox.

| File | Description |
|---|---|
| `models.py` | `Notification` model with title, message, type (`medication`, `birthday`, `refill`, etc.), read state, and optional pet link. |
| `views.py` | `NotificationViewSet` — list, create, and manage notifications. Supports `?unread=true` and `?pet_id=` query filters. Custom actions: `mark_read` / `mark_unread` on individual notifications. `check_birthdays` — creates a birthday notification for any pet whose birthday is today (deduplicated per day). `generate_test` — dev helper to create a test notification. |
| `serializers.py` | Serializer for notification read/create. |
| `urls.py` | URL patterns under `/api/notifications/`. |

---

## assessments/

Pet wellness assessments (Crossroads-style quality-of-life scoring).

| File | Description |
|---|---|
| `models.py` | `PetAssessment` stores the full answers JSON, computed `heart_score`, `condition_score`, and `significantly_challenged` flag, linked to a pet and the owner who submitted it. |
| `views.py` | `PetAssessmentViewSet` — list, create, and delete assessments, filterable by `?pet_id=`. Custom `share` action — sends a formatted email to a selected vet recipient (primary vet or specialist) with scores, individual category breakdowns, and owner notes. Uses SendGrid via Django's email backend. |
| `serializers.py` | Serializers for assessment create/read and the share request payload. |
| `urls.py` | URL patterns under `/api/assessments/`. |

---

## pet_calendar/

Daily check-ins, journal entries, and tags.

| File | Description |
|---|---|
| `models.py` | `DailyCheckin` — a good/bad day marker per pet per date. `JournalEntry` — free-text journal entry with optional photo, linked to a pet and date. `JournalTag` — user-defined color-coded tags applied to journal entries. |
| `views.py` | `DailyCheckinViewSet` — CRUD for check-ins, filterable by `?pet_id=` and `?date=`. `JournalEntryViewSet` — CRUD for journal entries with date-range and pet filters. `JournalPhotoUploadView` — multipart endpoint to attach a photo to a journal entry. `JournalTagViewSet` — CRUD for tags. |
| `permissions.py` | `JournalVisibilityPermission` and `IsAuthorForWriteOtherwiseReadOnly` — custom DRF permission classes controlling who can read vs. write journal content. |
| `serializers.py` | Serializers for all calendar models. |
| `urls.py` | URL patterns under `/api/calendar/`. |

---

## Infrastructure

| File | Description |
|---|---|
| `Dockerfile` | Builds the backend image from `python:3.12-slim`. Installs system deps, Python deps, and sets the entrypoint. |
| `docker/entrypoint.sh` | Container startup script. Waits for PostgreSQL, runs `migrate`, optionally runs `collectstatic`, then starts the server. |
| `requirements.txt` | Python package dependencies. |
| `manage.py` | Standard Django management command entry point. |
