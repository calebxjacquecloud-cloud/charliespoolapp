import { Link } from 'react-router-dom';
import { Empty } from '../components/ui';
import { BRAND } from '../brand';

export function NotFound() {
  return (
    <Empty title="Page not found">
      <Link to="/" className="btn-secondary mt-4">
        Back to {BRAND.bar}
      </Link>
    </Empty>
  );
}
