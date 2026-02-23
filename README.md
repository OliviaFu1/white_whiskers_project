# 🐾 White Whiskers Mobile App
Welcome to the **White Whiskers Mobile App** repository!  

---

## Tech Stack

- **Backend**: Django, Django REST Framework, PostgreSQL
- **Frontend**: Flutter (iOS / Android)
- **Database**: PostgreSQL (via Docker)

---

## Initialization
Follow these steps **once** after cloning the repository.

### 1. Create your local `.env` file
### 2. Start the database (Docker)

```bash
docker compose up -d
docker ps
```

### 3. Backend setup (Django)
```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

#### (On Windows)
```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

### 4. Run database migrations and start the backend
```bash
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

### 5. Frontend setup (Flutter)
```bash
cd frontend
flutter pub get
flutter run
```

---

## Daily Development Workflow
Start the database
```bash
docker compose up -d
```

Start the backend
```bash
cd backend
source .venv/bin/activate
python manage.py runserver
```

Start the frontend
```bash
cd frontend
flutter run
```

---

## Database Changes (Django Migrations)
**When you change models**
1. Update Django models
2. Run:
```bash
python manage.py makemigrations
python manage.py migrate
```
3. Commit the generated migration files

**After pulling changes**
```bash
python manage.py migrate
```
