import { DataProvider, fetchUtils } from 'react-admin';

const apiUrl = '/api/admin';

const httpClient = (url: string, options: fetchUtils.Options = {}) => {
  const token = localStorage.getItem('admin_token');
  const headers = new Headers(options.headers || { Accept: 'application/json' });

  if (token) {
    headers.set('Authorization', `Token ${token}`);
  }

  if (options.body && !(options.body instanceof FormData) && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json');
  }

  return fetchUtils.fetchJson(url, { ...options, headers });
};

const hasFile = (data: Record<string, unknown>) =>
  Object.values(data).some(
    (v) =>
      v instanceof File ||
      (v && typeof v === 'object' && 'rawFile' in (v as object)),
  );

const toFormData = (data: Record<string, unknown>): FormData => {
  const form = new FormData();
  Object.entries(data).forEach(([key, value]) => {
    if (value === undefined || value === null) return;
    if (value instanceof File) {
      form.append(key, value);
    } else if (value && typeof value === 'object' && 'rawFile' in value) {
      form.append(key, (value as { rawFile: File }).rawFile);
    } else if (Array.isArray(value)) {
      value.forEach((item) => form.append(key, String(item)));
    } else {
      form.append(key, String(value));
    }
  });
  return form;
};

const buildQuery = (params: {
  pagination?: { page: number; perPage: number };
  sort?: { field: string; order: string };
  filter?: Record<string, unknown>;
}) => {
  const { page = 1, perPage = 25 } = params.pagination || {};
  const { field = 'id', order = 'ASC' } = params.sort || {};
  const query = new URLSearchParams();
  query.set('page', String(page));
  query.set('page_size', String(perPage));
  if (field) {
    query.set('ordering', order === 'DESC' ? `-${field}` : field);
  }
  const search = params.filter?.q;
  if (search) query.set('search', String(search));
  return query.toString();
};

export const dataProvider: DataProvider = {
  getList: async (resource, params) => {
    const qs = buildQuery(params);
    const { json } = await httpClient(`${apiUrl}/${resource}/?${qs}`);
    return {
      data: json.results,
      total: json.count,
    };
  },

  getOne: async (resource, params) => {
    const { json } = await httpClient(`${apiUrl}/${resource}/${params.id}/`);
    return { data: json };
  },

  getMany: async (resource, params) => {
    const results = await Promise.all(
      params.ids.map((id) =>
        httpClient(`${apiUrl}/${resource}/${id}/`).then(({ json }) => json),
      ),
    );
    return { data: results };
  },

  getManyReference: async (resource, params) => {
    const filter = { ...params.filter, [params.target]: params.id };
    return dataProvider.getList(resource, { ...params, filter });
  },

  create: async (resource, params) => {
    const body = hasFile(params.data)
      ? toFormData(params.data as Record<string, unknown>)
      : JSON.stringify(params.data);
    const { json } = await httpClient(`${apiUrl}/${resource}/`, {
      method: 'POST',
      body,
    });
    return { data: json };
  },

  update: async (resource, params) => {
    const body = hasFile(params.data)
      ? toFormData(params.data as Record<string, unknown>)
      : JSON.stringify(params.data);
    const { json } = await httpClient(`${apiUrl}/${resource}/${params.id}/`, {
      method: 'PATCH',
      body,
    });
    return { data: json };
  },

  updateMany: async () => {
    throw new Error('updateMany дастгирӣ намешавад');
  },

  delete: async (resource, params) => {
    await httpClient(`${apiUrl}/${resource}/${params.id}/`, { method: 'DELETE' });
    return { data: params.previousData as any };
  },

  deleteMany: async (resource, params) => {
    await Promise.all(
      params.ids.map((id) =>
        httpClient(`${apiUrl}/${resource}/${id}/`, { method: 'DELETE' }),
      ),
    );
    return { data: [] };
  },
};
