import styles from './Tile.module.css';
// CSS Modules: class names are scoped to this file. styles.tile is a unique string.

type TileProps = {
    title: string; // required: a Tile with no title is not a Tile
    meta?: string; // "20 min · 1 missing". optional
    status?: 'ok' | 'warn'; // drives the meta colour via a data attribute
    
    onSelect?: () => void; // if present, the Tile is a button
};

export const Tile = ({ title, meta, status = 'ok', disabled = false, onSelect }: TileProps) => {
    // the inside is the same whether it's a button or a div, so build it once
    const content = (
        <>
            <span className={styles.title}>{title}</span>
            {meta && <span className={styles.meta}>{meta}</span>}
        </>
    );

// interactive? then it MUST be a real <button>. never a div with onClick.  
if  (onSelect) {
    return (
        <button 
            type="button" // without this, a button inside a form submits it
            className={styles.tile}
            data-status={status} // CSS hooks onto this, no extra class juggling
            
            onClick={onSelect}
        >{content}
        </button>
    );
}

return (
    <div className={styles.tile} data-status={status}>
        {content}
    </div>
);
}