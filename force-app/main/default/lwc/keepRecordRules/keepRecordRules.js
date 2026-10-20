import { LightningElement, track, wire } from 'lwc';
import { subscribe, onError } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getKeepRecordRules from '@salesforce/apex/MRG_KeepRecordRules_CTRL.getKeepRecordRules';
import getObjectFields from '@salesforce/apex/MRG_KeepRecordRules_CTRL.getObjectFields';
import getPreferences from '@salesforce/apex/MRG_KeepRecordRules_CTRL.getPreferences';
import saveKeepRecordRules from '@salesforce/apex/MRG_KeepRecordRules_CTRL.saveKeepRecordRules';

/**
 * Keep Record Rules editor: an ordered list of comparative preferences ("prefer the record whose
 * Relationship Manager has a value", then "prefer the oldest record"). Rows can be reordered,
 * added and removed; Save deploys the list for the selected object.
 */
export default class KeepRecordRules extends LightningElement {
    @track objectType = '';
    @track rules = [];
    @track fieldOptions = [];
    @track preferenceOptions = [];
    @track loading = false;
    @track saving = false;
    needsValueByPreference = {};

    objectOptions = [
        { label: 'Select an Object', value: '' },
        { label: 'Account', value: 'Account' },
        { label: 'Contact', value: 'Contact' }
    ];

    channelName = '/event/MergeRecordSave__e';

    connectedCallback() {
        this.registerErrorListener();
        this.handleSubscribe();
    }

    @wire(getPreferences)
    wiredPreferences({ data, error }) {
        if (data) {
            this.preferenceOptions = data.map((p) => ({ label: p.label, value: p.value }));
            const map = {};
            data.forEach((p) => { map[p.value] = p.needsValue === true; });
            this.needsValueByPreference = map;
            this.rules = this.decorate(this.rules);
        } else if (error) {
            this.handleError(error);
        }
    }

    get hasObject() {
        return this.objectType !== '' && this.objectType != null;
    }

    get hasRules() {
        return this.rules.length > 0;
    }

    get saveDisabled() {
        return this.saving || this.loading;
    }

    handleObjectChange(event) {
        this.objectType = event.detail.value;
        this.rules = [];
        if (this.hasObject) {
            this.loadFields();
            this.loadRules();
        }
    }

    loadFields() {
        getObjectFields({ objectType: this.objectType })
            .then((result) => {
                this.fieldOptions = result.map((f) => ({ label: f.label, value: f.name }));
            })
            .catch((error) => this.handleError(error));
    }

    loadRules() {
        this.loading = true;
        getKeepRecordRules({ objectType: this.objectType })
            .then((result) => {
                const rules = JSON.parse(JSON.stringify(result || []));
                rules.sort((a, b) => (a.order || 0) - (b.order || 0));
                this.rules = this.decorate(rules);
            })
            .catch((error) => this.handleError(error))
            .finally(() => { this.loading = false; });
    }

    // UI-only keys: stable row key, index, 1-based position, value visibility, move button state
    decorate(rules) {
        const count = rules.length;
        return rules.map((rule, i) => {
            const out = Object.assign({}, rule);
            out.uiKey = rule.uiKey || ('rule-' + Date.now() + '-' + Math.random());
            out.index = i;
            out.position = i + 1;
            out.needsValue = this.needsValueByPreference[rule.preference] === true;
            if (!out.needsValue) {
                out.value = null;
            }
            out.isFirst = i === 0;
            out.isLast = i === count - 1;
            return out;
        });
    }

    addRule() {
        const rule = {
            id: null,
            label: null,
            objectName: this.objectType,
            order: this.rules.length + 1,
            fieldName: '',
            preference: 'HasValue',
            value: null,
            active: true
        };
        this.rules = this.decorate([...this.rules, rule]);
    }

    removeRule(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        const rules = [...this.rules];
        rules.splice(idx, 1);
        this.rules = this.decorate(rules);
    }

    moveUp(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        if (idx <= 0) {
            return;
        }
        const rules = [...this.rules];
        [rules[idx - 1], rules[idx]] = [rules[idx], rules[idx - 1]];
        this.rules = this.decorate(rules);
    }

    moveDown(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        if (idx >= this.rules.length - 1) {
            return;
        }
        const rules = [...this.rules];
        [rules[idx + 1], rules[idx]] = [rules[idx], rules[idx + 1]];
        this.rules = this.decorate(rules);
    }

    handleFieldChange(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        const rules = [...this.rules];
        rules[idx] = Object.assign({}, rules[idx], { fieldName: event.detail.value });
        this.rules = this.decorate(rules);
    }

    handlePreferenceChange(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        const rules = [...this.rules];
        rules[idx] = Object.assign({}, rules[idx], { preference: event.detail.value });
        this.rules = this.decorate(rules);
    }

    handleValueChange(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        const rules = [...this.rules];
        rules[idx] = Object.assign({}, rules[idx], { value: event.target.value });
        this.rules = this.decorate(rules);
    }

    // the rules in evaluation order with the UI-only keys stripped
    get payload() {
        return this.rules.map((rule, i) => ({
            id: rule.id || null,
            label: rule.label || null,
            objectName: this.objectType,
            order: i + 1,
            fieldName: rule.fieldName,
            preference: rule.preference,
            value: rule.needsValue ? rule.value : null,
            active: true
        }));
    }

    handleSave() {
        this.saving = true;
        saveKeepRecordRules({ objectType: this.objectType, jsonData: JSON.stringify(this.payload) })
            .then((jobId) => {
                if (!jobId) {
                    // nothing stored and nothing to store: no deploy was queued
                    this.saving = false;
                    this.showNotification('Keep Record Rules', 'Nothing to save.', 'info');
                }
                // otherwise the deploy result arrives through the platform-event subscription
            })
            .catch((error) => {
                this.saving = false;
                this.handleError(error);
            });
    }

    // --- platform event + notifications (same pattern as the other settings tabs) ---

    handleSubscribe() {
        const messageCallback = (response) => {
            const payload = response && response.data && response.data.payload;
            if (!payload) {
                return;
            }
            if (payload.IsSuccess__c === true) {
                this.handleSuccess();
            } else if (this.saving) {
                this.saving = false;
                this.showNotification('Keep Record Rules not saved', payload.Message__c || 'The metadata deployment failed.', 'error');
            }
        };
        subscribe(this.channelName, -1, messageCallback).then((response) => {
            this.subscription = response;
        });
    }

    registerErrorListener() {
        onError((error) => this.handleError(error));
    }

    handleSuccess() {
        this.saving = false;
        this.showNotification('Keep Record Rules saved', '', 'success');
        if (this.hasObject) {
            this.loadRules();
        }
    }

    handleError(error) {
        let body = 'Unknown error';
        if (error && error.body) {
            if (Array.isArray(error.body)) {
                body = error.body.map((e) => e.message).join(', ');
            } else if (typeof error.body.message === 'string') {
                body = error.body.message;
            }
        } else if (error && typeof error.message === 'string') {
            body = error.message;
        }
        this.showNotification('An error has occurred', body, 'error');
    }

    showNotification(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
