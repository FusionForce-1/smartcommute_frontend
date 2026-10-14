// js/config.js
//
// Web portal runtime config. Point this at the FastAPI backend.
// The page's origin must be listed in the backend's ALLOWED_ORIGINS (.env).

// Opened from this computer (Live Server, localhost / 127.0.0.1) -> the
// local backend; anywhere else (e.g. deployed on Vercel) -> the cloud one.
const LOCAL_API_BASE_URL = 'http://localhost:8000';
const CLOUD_API_BASE_URL = 'https://smart-commute-backend.onrender.com';
const API_BASE_URL = ['localhost', '127.0.0.1'].includes(location.hostname)
  ? LOCAL_API_BASE_URL
  : CLOUD_API_BASE_URL;

// OAuth "Web application" client ID — must match GOOGLE_CLIENT_ID in the
// backend .env (the backend verifies Google tokens against it). The page's
// origin (e.g. http://127.0.0.1:5500) must be listed under "Authorized
// JavaScript origins" for this client in Google Cloud Console.
const GOOGLE_CLIENT_ID = '545428320814-dm6hnjft2jcdia4fkn78glhh2fn5v93i.apps.googleusercontent.com';
