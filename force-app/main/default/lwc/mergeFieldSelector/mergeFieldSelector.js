import { LightningElement, api } from 'lwc';

/**
 * Autocomplete field picker. Once the user types at least MIN_CHARS characters, it shows the
 * fields whose label OR API name contains the typed text, each as "label (api name)". Emits a
 * `change` CustomEvent with { value } (the api name), so it is a drop-in replacement for a field
 * lightning-combobox (parent handlers read event.detail.value and event.target.dataset.*).
 */
const MIN_CHARS = 3;

export default class MergeFieldSelector extends LightningElement {
    @api label;
    @api placeholder = 'Search fields...';
    @api disabled = false;

    _options = [];
    @api
    get options() {
        return this._options;
    }
    set options(value) {
        this._options = (value || []).map(o => ({ label: o.label, value: o.value, display: o.label + ' (' + o.value + ')' }));
        this.syncDisplay();
    }

    _value;
    @api
    get value() {
        return this._value;
    }
    set value(v) {
        this._value = v;
        this.syncDisplay();
    }

    // active search text — drives the result list only. The input itself is UNCONTROLLED (no
    // value binding) so re-renders never reset it mid-typing.
    query = '';
    open = false;
    _pendingDisplaySync = false;
    _mouseInside = false;

    connectedCallback() {
        // close the list on an outside click (not on blur — blur fires when the user grabs the
        // dropdown's scrollbar, which would wrongly close it)
        this._onDocumentMouseDown = () => {
            if (!this._mouseInside) {
                this.open = false;
            }
            this._mouseInside = false;
        };
        document.addEventListener('mousedown', this._onDocumentMouseDown);
    }

    disconnectedCallback() {
        document.removeEventListener('mousedown', this._onDocumentMouseDown);
    }

    // a mousedown anywhere within this component (input, list or its scrollbar) is "inside"
    handleRootMouseDown() {
        this._mouseInside = true;
    }

    // text shown for the current selection ("label (api name)")
    get displayValue() {
        if (this._value == null || this._value === '') {
            return '';
        }
        const selected = this._options.find(o => o.value === this._value);
        return selected ? selected.display : this._value;
    }

    // push the selection text into the uncontrolled input imperatively (the only writes to it)
    syncDisplay() {
        const input = this.template.querySelector('input');
        if (!input) {
            this._pendingDisplaySync = true; // input not rendered yet; apply after render
            return;
        }
        // never overwrite what the user is actively typing (e.g. a parent re-render landing mid-type)
        if (this.template.activeElement === input) {
            return;
        }
        input.value = this.displayValue;
    }

    renderedCallback() {
        if (this._pendingDisplaySync) {
            this._pendingDisplaySync = false;
            this.syncDisplay();
        }
    }

    // when the box is just showing the current selection that is not a search
    get searchTerm() {
        if (this.query === this.displayValue) {
            return '';
        }
        return (this.query || '').trim();
    }

    get filtered() {
        const q = this.searchTerm.toLowerCase();
        if (q.length < MIN_CHARS) {
            return [];
        }
        return this._options.filter(o => o.label.toLowerCase().includes(q) || o.value.toLowerCase().includes(q));
    }

    get hasResults() {
        return this.open && this.filtered.length > 0;
    }

    handleFocus() {
        this.open = true;
    }
    handleInput(event) {
        this.query = event.target.value;
        this.open = true;
    }
    handleSelect(event) {
        const value = event.currentTarget.dataset.value;
        this._value = value;
        this.query = this.displayValue;
        const input = this.template.querySelector('input');
        if (input) {
            input.value = this.displayValue;
        }
        this.open = false;
        this.dispatchEvent(new CustomEvent('change', { detail: { value } }));
    }
}
