# PageFlow — SaaS Starter

A production-ready SaaS starter built with **Next.js 15 App Router**, **Tailwind CSS**, and **Supabase** authentication.

## Stack

- **Next.js 15** (App Router)
- **TypeScript**
- **Tailwind CSS** (dark theme)
- **Supabase** (auth + database)
- **Lucide React** (icons)

## Project Structure

```
saas-starter/
├── app/
│   ├── layout.tsx               # Root layout
│   ├── page.tsx                 # Landing page
│   ├── globals.css
│   ├── auth/
│   │   └── page.tsx             # Login + Signup
│   ├── dashboard/
│   │   ├── layout.tsx           # Sidebar layout
│   │   ├── page.tsx             # Dashboard overview
│   │   ├── pages/page.tsx       # Facebook Pages UI
│   │   ├── automation/page.tsx  # Automation workflows
│   │   ├── ai-settings/page.tsx # AI configuration
│   │   └── leads/page.tsx       # Leads CRM
│   └── api/
│       └── pages/route.ts       # REST API example
├── components/
│   └── Sidebar.tsx              # Navigation sidebar
├── lib/
│   ├── supabase.ts              # Browser Supabase client
│   └── supabase-server.ts       # Server Supabase client
├── middleware.ts                 # Auth route protection
└── .env.local.example
```

## Quick Start

### 1. Install dependencies

```bash
npm install
```

### 2. Set up Supabase

1. Create a project at [supabase.com](https://supabase.com)
2. Go to **Project Settings → API**
3. Copy your **Project URL** and **anon/public key**

### 3. Configure environment variables

```bash
cp .env.local.example .env.local
```

Edit `.env.local`:

```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key-here
```

### 4. Enable Email Auth in Supabase

Go to **Authentication → Providers → Email** and ensure it's enabled.

### 5. Run the development server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

## Features

| Feature | Description |
|---|---|
| ✅ Auth | Email/password login & signup via Supabase |
| ✅ Protected routes | Middleware redirects unauthenticated users |
| ✅ Sidebar layout | Collapsible nav across all dashboard pages |
| ✅ Pages UI | Grid view of Facebook pages with connect modal |
| ✅ Automation | Toggle, manage, and view automation workflows |
| ✅ AI Settings | Configure AI persona, tone, language, safety |
| ✅ Leads CRM | Table view with search, filter, and score |
| ✅ API routes | Authenticated REST endpoints with Supabase |

## API Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/api/pages` | List pages for authenticated user |
| POST | `/api/pages` | Create a new page |

## Deployment

Deploy to Vercel:

```bash
npx vercel
```

Add the same environment variables in your Vercel project settings.
