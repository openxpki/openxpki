import getConfig from '../config/environment';

export default getConfig(import.meta.env.MODE || 'development');
