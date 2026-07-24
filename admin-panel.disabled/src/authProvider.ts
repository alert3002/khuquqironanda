import { AuthProvider, HttpError } from 'react-admin';

const httpClient = async (url: string, options: RequestInit = {}) => {
  const headers = new Headers(options.headers);
  headers.set('Accept', 'application/json');
  if (options.body) headers.set('Content-Type', 'application/json');
  const response = await fetch(url, { ...options, headers });
  const json = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new HttpError(
      (json as { error?: string }).error || response.statusText,
      response.status,
      json,
    );
  }
  return json;
};

export const authProvider: AuthProvider = {
  login: async ({ username, password }) => {
    const data = await httpClient('/api/admin/auth/login/', {
      method: 'POST',
      body: JSON.stringify({ phone: username, password }),
    });
    localStorage.setItem('admin_token', data.token);
    localStorage.setItem('admin_user', JSON.stringify(data));
    return data;
  },

  logout: () => {
    localStorage.removeItem('admin_token');
    localStorage.removeItem('admin_user');
    return Promise.resolve();
  },

  checkAuth: () =>
    localStorage.getItem('admin_token') ? Promise.resolve() : Promise.reject(),

  checkError: (error) => {
    if (error.status === 401 || error.status === 403) {
      localStorage.removeItem('admin_token');
      return Promise.reject();
    }
    return Promise.resolve();
  },

  getIdentity: () => {
    const raw = localStorage.getItem('admin_user');
    if (!raw) return Promise.reject();
    const user = JSON.parse(raw);
    return Promise.resolve({
      id: user.id,
      fullName: user.fullName || user.phone,
    });
  },

  getPermissions: () => Promise.resolve('admin'),
};
