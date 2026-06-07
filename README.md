# AI PATHSHALA

![AI Pathshala](https://img.shields.io/badge/AI-SaaS-blue) ![Live](https://img.shields.io/badge/Live-App-green) ![Made with Lovable](https://img.shields.io/badge/Built%20with-Lovable-emerald)

## Repository Structure

```
AI-PathShala-Repo-for-caps/
├── FrontEnd/    ← React 19 + Vite + TanStack (Lovable generated code)
├── BackEnd/     ← Make.com automation workflow config (JSON)
└── README.md    ← Project documentation
```

---

## Product Overview

AI PATHSHALA is a modern AI-powered lesson creation SaaS built for educators and schools. It enables teachers to generate complete lesson plans, quizzes, worksheets, homework templates, and student announcements using AI, while centralizing class content and analytics in a polished web dashboard.

## Problem Solved

Teachers and curriculum designers spend too much time creating lesson materials, assessments, and student communications manually. This product reduces repetitive lesson planning work, streamlines content publishing, and helps schools deliver scalable AI-driven learning experiences.

## Solution Architecture

AI PATHSHALA is implemented as a hybrid React + server-function SaaS platform:

- **Client UI:** React 19 + Vite + TanStack Router + Tailwind
- **Auth & Data:** Supabase for authentication, role-based access, and lesson storage
- **AI services:** Gemini via Lovable AI Gateway for lesson generation, RapidAPI for YouTube transcript extraction, and Gemini image analysis for visual lesson source content
- **Export:** PDF/DOCX lesson and report generation in the browser
- **Hosting-ready:** Cloudflare Workers / Vite Cloudflare integration via Wrangler

```mermaid
graph TD
    subgraph USERS["👥 Users"]
        T["🎓 Teacher"]
        S["📚 Student"]
        P["🏫 Principal"]
    end

    subgraph FRONTEND["🌐 Frontend — React 19 + Vite + Tailwind + TanStack Router"]
        UI["Web App UI"]
        AUTH["Auth Pages\n(Sign In / Sign Up)"]
        DASH["Dashboards\n(Teacher / Student / Principal)"]
        CREATE["Lesson Creator\n(4 input modes)"]
        EXPORT["PDF / DOCX Export\njsPDF · docx · html2canvas"]
    end

    subgraph BACKEND["⚙️ Backend — TanStack Start Server Functions"]
        LFN["lesson.functions.ts\nLesson Generation"]
        YFN["youtube.functions.ts\nYouTube Transcripts"]
        IFN["image.functions.ts\nImage Analysis"]
        EFN["email-notify.functions.ts\nEmail Notifications"]
    end

    subgraph DATABASE["🗄️ Supabase"]
        PG["Postgres DB\nLessons · Profiles · Quiz Attempts"]
        STORAGE["File Storage\nHomework Uploads"]
        RLS["Row-Level Security\nRole-Based Access"]
    end

    subgraph AI["🤖 AI Services"]
        GEMINI["Google Gemini 2.5 Flash\nLesson Generation"]
        RAPID["RapidAPI\nYouTube Transcripts"]
        VISION["Gemini Vision\nImage Analysis"]
    end

    subgraph DELIVERY["📧 Email Delivery"]
        MAKE["Make.com\nCustom Webhook"]
        HTTP["HTTP Module\nGemini Email Writer"]
        RESEND["Resend API\nEmail Delivery"]
    end

    T & S & P --> UI
    UI --> AUTH
    AUTH --> DATABASE
    UI --> DASH
    UI --> CREATE
    CREATE --> BACKEND
    LFN --> GEMINI
    YFN --> RAPID
    IFN --> VISION
    EFN --> MAKE
    MAKE --> HTTP
    HTTP --> RESEND
    RESEND -->|"📬 Email Alert"| S
    BACKEND --> DATABASE
    DASH --> DATABASE
    CREATE --> EXPORT
```

## Features

- ✅ AI lesson generation with structured learning objectives, quizzes, and homework
- ✅ YouTube transcript import for rapid lesson building
- ✅ Image-based lesson creation from diagrams, notes, or textbook pages
- ✅ Teacher and student role management using Supabase auth
- ✅ Export lessons and reports to PDF/DOCX
- ✅ Automated lesson announcements via Make.com + Resend email
- ✅ Subject curriculum suggestions for AI, Python, web development, robotics, and data science
- ✅ Multilingual support — English, Hindi, Roman Hindi, Arabic (RTL)
- ✅ Responsive dashboard and lesson workflow for teachers, students, and principals

## Workflow Explanation

1. **Sign in / sign up** using Supabase authentication.
2. **Select subject, grade, and topic** from curated curriculum suggestions.
3. **Generate a lesson** using AI with optional source text, YouTube URL, or image upload.
4. **Review and edit** the generated lesson, worksheet, quiz, and homework content.
5. **Export** the lesson as PDF or DOCX for offline teaching.
6. **Notify students** with automated email announcements via Make.com.
7. **Track progress** through student and principal dashboards.

## Tech Stack

- Frontend: React 19, Vite, Tailwind CSS, TanStack Router
- Backend / Functions: `@tanstack/react-start`, Supabase server functions
- Database: Supabase Postgres + Storage + Row-Level Security
- AI: Google Gemini 2.5 Flash, RapidAPI (YouTube), Gemini Vision (images)
- Automation: Make.com webhooks + HTTP + Resend email delivery
- Export: jsPDF, docx, html2canvas
- Deployment: Cloudflare Workers / Wrangler, Vite build

## Installation Steps

```bash
git clone https://github.com/Faisal01984/AI-PathShala-Repo-for-caps
cd AI-PathShala-Repo-for-caps/FrontEnd
npm install
cp .env.example .env
# update .env with your Supabase, Gemini, RapidAPI, and Lovable API keys
npm run dev
```

## Environment Variables

Create or update `FrontEnd/.env` with the following values:

```env
SUPABASE_URL="https://YOUR_SUPABASE_PROJECT.supabase.co"
VITE_SUPABASE_PROJECT_ID="YOUR_SUPABASE_PROJECT_ID"
VITE_SUPABASE_PUBLISHABLE_KEY="YOUR_SUPABASE_PUBLISHABLE_KEY"
SUPABASE_PUBLISHABLE_KEY="YOUR_SUPABASE_PUBLISHABLE_KEY"
SUPABASE_SERVICE_ROLE_KEY="YOUR_SUPABASE_SERVICE_ROLE_KEY"
LOVABLE_API_KEY="YOUR_LOVABLE_API_KEY"
GEMINI_API_KEY="YOUR_GEMINI_API_KEY"
RAPIDAPI_KEY="YOUR_RAPIDAPI_KEY"
```

> Note: keep all service keys private and do not commit `.env` to source control.

## Screenshots

| Dashboard | Lesson Creation |
|---|---|
| ![Teacher Dashboard](Screenshot/2%20Teacher's%20Dashboard.png) | ![Lesson Creation page](Screenshot/3%20Lesson%20Creation%20page.png) |

| Lesson Library | Student Progress |
|---|---|
| ![Lesson Library](Screenshot/4%20Lesson%20Library.png) | ![Student Progress Report](Screenshot/5%20Student%20Progress%20Report%20in%20Teacher%20Dashboard.png) |

| Principal Overview |
|---|
| ![Principal Dashboard](Screenshot/7%20All%20Students%20Progress%20in%20Principal's%20Dashboard.png) |

## Project Explainer Images

| Explainer 1 | Explainer 2 |
|---|---|
| ![Project Explainer 1](Project%20Explainer%20image%201.png) | ![Project Explainer 2](Project%20Explainer%20image%202.jpg) |

## Deployment Links

- **Live App:** [https://ai-pathshala-creations.lovable.app](https://ai-pathshala-creations.lovable.app)
- **Main Code Repo:** [https://github.com/Faisal01984/ai-pathshala-creations](https://github.com/Faisal01984/ai-pathshala-creations)

## Future Roadmap

- 🚀 Mobile app or PWA support for teacher and student access
- 🔧 LMS and Google Classroom integration
- 📊 Analytics dashboard for lesson usage and engagement
- 🤖 AI tutor chat and student feedback assistant
- 🌍 Multilingual lesson generation for global education
- 🧩 Collaboration tools for co-teaching and curriculum sharing

## Creator Information

Created by Mohd Faisal.

- **Live App:** [https://ai-pathshala-creations.lovable.app](https://ai-pathshala-creations.lovable.app)
- **Contact:** faisal01984@gmail.com

## License

MIT License
