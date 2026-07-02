import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { getToken } from './api';
import SignIn from './pages/SignIn';
import Timeline from './pages/Timeline';
import EntryEditor from './pages/EntryEditor';
import Calendar from './pages/Calendar';
import Garden from './pages/Garden';
import Review from './pages/Review';
import PrintView from './pages/PrintView';
import SearchOverlay from './components/SearchOverlay';
import PinLock from './components/PinLock';

function Private({ children }) {
  return getToken() ? children : <Navigate to="/" replace />;
}

function Root() {
  return getToken() ? <Navigate to="/timeline" replace /> : <SignIn />;
}

export default function App() {
  return (
    <BrowserRouter>
      <PinLock />
      <SearchOverlay />
      <Routes>
        <Route path="/" element={<Root />} />
        <Route path="/timeline" element={<Private><Timeline /></Private>} />
        <Route path="/entry/new" element={<Private><EntryEditor /></Private>} />
        <Route path="/entry/:id" element={<Private><EntryEditor /></Private>} />
        <Route path="/calendar" element={<Private><Calendar /></Private>} />
        <Route path="/garden" element={<Private><Garden /></Private>} />
        <Route path="/review" element={<Private><Review /></Private>} />
        <Route path="/print" element={<Private><PrintView /></Private>} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
