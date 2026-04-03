// Test environment setup — loads .env and sets test-specific overrides
import 'dotenv/config';

// Use a dedicated test JWT secret so tests don't depend on production secrets
process.env.JWT_SECRET          = process.env.JWT_SECRET          ?? 'test-jwt-secret-32-chars-minimum!!';
process.env.JWT_REFRESH_SECRET  = process.env.JWT_REFRESH_SECRET  ?? 'test-refresh-secret-32-chars-min!';
process.env.JWT_EXPIRES_IN      = '1h';
process.env.JWT_REFRESH_EXPIRES_IN = '7d';
