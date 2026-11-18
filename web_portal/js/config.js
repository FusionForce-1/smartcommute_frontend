// Portal config
const LOCAL_API_BASE_URL = 'http://localhost:8000';
const CLOUD_API_BASE_URL = 'https://smart-commute-backend.onrender.com';
const API_BASE_URL = ['localhost', '127.0.0.1'].includes(location.hostname)
  ? LOCAL_API_BASE_URL
  : CLOUD_API_BASE_URL;

const GOOGLE_CLIENT_ID = '545428320814-dm6hnjft2jcdia4fkn78glhh2fn5v93i.apps.googleusercontent.com';
