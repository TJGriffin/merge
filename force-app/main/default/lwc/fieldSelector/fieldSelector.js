import { LightningElement, api, track } from 'lwc';

/**
 * Autocomplete field picker. Filters as you type on EITHER the field label or the API name and
 * shows each result as "label (api name)". Emits a `change` CustomEvent with { value } (the api
 * name), so it is a drop-in replacement for a field lightning-combobox (parent handlers read
 * event.detail.value and event.target.dataset.*).
 */
export default class FieldSelector extends LightningElement {
    @api label;
    @api placeholder = 'Search fields...';
    @api disabled = false;

    @track _options = [];
    @api
    get options() {
        return this._options;
    }
    set options(value) {
        this._options = (value || []).map(o => ({ label: o.label, value: o.value, display: o.label + ' (' + o.value + ')' }));
        this.syncQuery();
    }

    @track _value;
    @api
    get value() {
        return this._value;
    }
    set value(v) {
        this._value = v;
        this.syncQuery();
    }

    @track query = '';
    @track open = false;

    // show the current selection as "label (api)" in the input
    syncQuery() {
        if (this._value == null || this._value === '') {
            this.query = '';
            return;
        }
        const selected = this._options.find(o => o.value === this._value);
        this.query = selected ? selected.display : this._value;
    }

    get filtered() {
        const selected = this._options.find(o => o.value === this._value);
        // when the box still shows the current selection, list everything (browsing, not filtering)
        if (selected && this.query === selected.display) {
            return this._options;
        }
        const q = (this.query || '').toLowerCase().trim();
        if (!q) {
            return this._options;
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
    handleBlur() {
        this.open = false;
    }
    // mousedown fires before the input's blur, so the selection registers before the list closes
    handleSelect(event) {
        const value = event.currentTarget.dataset.value;
        this._value = value;
        this.syncQuery();
        this.open = false;
        this.dispatchEvent(new CustomEvent('change', { detail: { value } }));
    }
}
