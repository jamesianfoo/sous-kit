import React from 'react';
import ReactDOM from 'react-dom/client';
import './styles/tokens.css';
import './styles/base.css';
import { Tile } from './components/Tile/Tile';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <div style={{ maxWidth: 360 }}>
      <Tile
        title="Garlic prawn linguine"
        meta="20 min · 1 missing"
        status="warn"
        onSelect={() => console.log('picked prawns')}
      />
     
    </div>

  </React.StrictMode>
);