# CREANNO — Cross-Platform Company Management App

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev/)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android-blue)]()
[![License](https://img.shields.io/badge/License-Proprietary-red)]()

> Built by **Smart Innovations** — Capstone Project 2025–26

A full-stack company management app for small/medium Indian businesses — built for event agencies, marketing studios, and service teams. **Runs on Windows desktop + Android mobile from a single codebase.**

---

## 🌐 Live URLs

| Resource | URL |
|---|---|
| 🔗 **Backend (Railway)** | `https://backend-production-8b728.up.railway.app/api` |
| 🐙 **Backend Repo** | https://github.com/Lokesh-creanno/company-app-backend |
| 🐙 **Frontend Repo** | https://github.com/Lokesh-creanno/company-app-frontend |

---

## ✨ Features

### Team Productivity
- 📅 **Calendar-first Tasks** — colour-coded priority dots, monthly view, instant filter
- ⏰ **Attendance** — one-tap check-in/out with timestamp + optional GPS
- 🧾 **Expense Claims** — multi-step form, PDF generation, embedded receipts
- 📁 **Documents** — secure team document repository

### AI-Powered (Google Gemini 1.5 Flash — Free Tier)
- 🎯 **Task Auto-Assignment** — AI ranks team members by match score (0-100)
- 📅 **Daily Work Planner** — generates time-blocked schedules per member
- 🔔 **Smart Alerts** — analyses team data, groups alerts by urgency
- 🐛 **Error Monitor** — captures all errors, AI explains root cause + fix
- 💡 **Dashboard Insights** — personalised daily briefings every morning

### On-Device AI (Google ML Kit)
- 🧾 **Receipt OCR** — scan printed bills, auto-fill amount/vendor/date
- 🌐 **Latin + Devanagari** — reads both English and Hindi receipts
- ⚡ **Offline-first** — runs entirely on-device, no API costs

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.x (Dart) |
| **State** | Riverpod 2 |
| **Routing** | go_router |
| **Network** | Dio |
| **AI — LLM** | `google_generative_ai` (Gemini 1.5 Flash) |
| **AI — Vision** | `google_mlkit_text_recognition` (on-device OCR) |
| **Backend** | Node.js + Express on Railway |
| **Database** | Supabase PostgreSQL |
| **Auth** | Email OTP (passwordless) |
| **Installer** | Inno Setup 6 (Windows) |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.x+
- Android Studio (for Android builds)
- Visual Studio with C++ workload (for Windows builds)
- A free Gemini API key from [aistudio.google.com](https://aistudio.google.com/app/apikey)

### Setup

```bash
git clone https://github.com/Lokesh-creanno/company-app-frontend.git
cd company-app-frontend
flutter pub get
# Edit lib/core/ai_config.dart and paste your free Gemini key
```

### Configure Backend URL (Optional)

By default, the app connects to the production Railway backend. To use your own backend:

```bash
flutter run --dart-define=API_BASE_URL=https://your-backend.com/api
```

### Run

```bash
flutter run -d android    # Android
flutter run -d windows    # Windows desktop
flutter run -d chrome     # Web (limited features)
```

### Build Releases

```bash
flutter build apk --release         # Android APK
flutter build windows --release     # Windows EXE
# Then open mobile/windows/installer.iss in Inno Setup → Build
```

---

## 📁 Project Structure

```
lib/
├── core/                # App-wide config, routing, theme, constants
├── features/
│   ├── admin/           # Admin panel + AI Command Center + Error Console
│   ├── attendance/      # Check-in / check-out + calendar
│   ├── auth/            # Login + OTP screens
│   ├── calendar/        # Agency calendar
│   ├── dashboard/       # Home dashboard with AI Insights
│   ├── documents/       # Team document repository
│   ├── employees/       # Team Member directory & profile
│   ├── reimbursement/   # Expense claims + PDF generator
│   └── tasks/           # Calendar-first task management
└── shared/
    ├── services/        # ai_service, api_service, error_log_service, ...
    └── widgets/         # Reusable UI components
```

---

## 🤖 AI Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              CREANNO Flutter App  (this repo)               │
│                                                              │
│  ┌──────────────────────┐    ┌──────────────────────────┐   │
│  │ google_generative_ai │    │ google_mlkit_text_recog. │   │
│  │  (Gemini 1.5 Flash)  │    │      (On-device OCR)     │   │
│  └──────────┬───────────┘    └──────────┬───────────────┘   │
│             │                            │                   │
│             ▼                            ▼                   │
│      ☁️  Cloud API                  📲  Local Engine        │
│   (1,500 req/day free)        (Zero cost, no network)       │
└──────────────────────────────────┬──────────────────────────┘
                                   │
                                   ▼
                         🌐 Railway Backend (REST API)
                                   │
                                   ▼
                         🗄  Supabase PostgreSQL
```

---

## 📦 Distribution

| Platform | Artifact | Size |
|---|---|---|
| Android | `CREANNO_v1.4.0.apk` | ~44 MB |
| Windows | `CREANNO_Setup_v1.4.0.exe` | ~13 MB |

---

## 📄 License

Proprietary — © 2025–26 Smart Innovations. All rights reserved.

---

## 🙋 Built By

**Lokesh** — Smart Innovations  
Capstone Project | 2025–26
