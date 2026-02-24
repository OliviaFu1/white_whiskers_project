# 🐾 White Whiskers Mobile App

Welcome to the **White Whiskers Mobile App** repository!

---

## 🧱 Tech Stack

- **Backend**: Django, Django REST Framework (Dockerized)
- **Frontend**: Flutter (iOS / Android)
- **Database**: PostgreSQL (Docker)
- **Containerization**: Docker & Docker Compose

---

# 🚀 Initialization (First Time Setup)

Follow these steps **once** after cloning the repository.

---

## 1️⃣ Create your local `.env` file

Create a `.env` file in the project root with:

```env
DJANGO_SECRET_KEY=your-secret-key
DJANGO_DEBUG=True

POSTGRES_DB=petcare
POSTGRES_USER=petcare_user
POSTGRES_PASSWORD=petcare_password
POSTGRES_HOST=db
POSTGRES_PORT=5432
```

---

## 2️⃣ Start Backend + Database (Docker)

From the project root:

```bash
docker compose up --build
```

This will:

- Start PostgreSQL
- Wait for database readiness
- Run Django migrations automatically
- Collect static files
- Start the Django development server

Backend will be available at:

```
http://localhost:8000
```

---

## 3️⃣ Create Superuser (One Time)

In a new terminal:

```bash
docker compose run --rm backend python manage.py createsuperuser
```

---

## 4️⃣ Frontend Setup (Flutter)

```bash
cd frontend
flutter pub get
flutter run
```

---

# 🔁 Daily Development Workflow

## Start everything

```bash
docker compose up
```

## Stop everything

```bash
docker compose down
```

---

# 🗄️ Database Notes

### Reset the database completely

⚠️ This deletes all data.

```bash
docker compose down -v
docker compose up --build
```

---

# 🧩 Database Changes (Django Migrations)

### When you change models:

```bash
docker compose run --rm backend python manage.py makemigrations
docker compose run --rm backend python manage.py migrate
```

Commit the generated migration files.

---

### After pulling new changes:

```bash
docker compose run --rm backend python manage.py migrate
```

---

# 🛠️ Useful Commands

### View logs

```bash
docker compose logs -f
```

### Access Django shell

```bash
docker compose run --rm backend python manage.py shell
```

### Rebuild containers

```bash
docker compose up --build
```
