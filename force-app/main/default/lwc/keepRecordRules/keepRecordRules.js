import { LightningElement, track, wire } from 'lwc';
import { subscribe, onError } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getKeepRecordRules from '@salesforce/apex/MRG_KeepRecordRules_CTRL.getKeepRecordRules';
import getObjectFields from '@salesforce/apex/MRG_KeepRecordRules_CTRL.getObjectFields';
import getOperators from '@salesforce/apex/MRG_KeepRecordRules_CTRL.getOperators';
import saveKeepRecordRules from '@salesforce/apex/MRG_KeepRecordRules_CTRL.saveKeepRecordRules';

export default class KeepRecordRules extends LightningElement {
    @track objectType = '';
    @track rules = [];
    @track fieldOptions = [];
    @track operatorOptions = [];
    fieldTypeByName = {};

    objectOptions = [
        { label: 'Select an Object', value: '' },
        { label: 'Account', value: 'Account' },
        { label: 'Contact', value: 'Contact' }
    ];

    channelName = '/event/MergeRecordSave__e';
    notificationTitle;
    notificationBody;
    notificationStyle;

    connectedCallback() {
        this.registerErrorListener();
        this.handleSubscribe();
    }

    @wire(getOperators)
    wiredOperators({ data }) {
        if (data) {
            this.operatorOptions = data;
        }
    }

    get hasObject() {
        return this.objectType !== '' && this.objectType != null;
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
                const map = {};
                result.forEach((f) => { map[f.name] = f.type; });
                this.fieldTypeByName = map;
            })
            .catch((error) => this.handleError(error));
    }

    loadRules() {
        getKeepRecordRules({ objectType: this.objectType })
            .then((result) => {
                this.rules = this.decorate(JSON.parse(JSON.stringify(result)));
            })
            .catch((error) => this.handleError(error));
    }

    // add UI-only keys (stable row keys, indices for event handlers, per-condition input type)
    decorate(rules) {
        const decorated = rules.map((rule, ri) => {
            rule.uiKey = 'rule-' + ri + '-' + Date.now();
            rule.ruleIndex = ri;
            rule.conditions = (rule.conditions || []).map((c, ci) => this.decorateCondition(c, ri, ci));
            return rule;
        });
        return decorated;
    }

    decorateCondition(condition, ri, ci) {
        condition.uiKey = 'cond-' + ri + '-' + ci + '-' + Date.now();
        condition.ruleIndex = ri;
        condition.conditionIndex = ci;
        const type = this.fieldTypeByName[condition.fieldName];
        condition.inputType = this.inputTypeForFieldType(type);
        condition.isCheckbox = condition.inputType === 'checkbox';
        condition.checked = condition.isCheckbox && condition.value === 'true';
        return condition;
    }

    inputTypeForFieldType(fieldType) {
        switch (fieldType) {
            case 'BOOLEAN': return 'checkbox';
            case 'DATE': return 'date';
            case 'DATETIME': return 'datetime-local';
            case 'DOUBLE':
            case 'CURRENCY':
            case 'INTEGER':
            case 'LONG':
            case 'PERCENT': return 'number';
            default: return 'text';
        }
    }

    addRule() {
        const order = this.rules.length + 1;
        const rule = {
            id: null,
            label: this.objectType + ' Keep Rule ' + order,
            objectName: this.objectType,
            order: order,
            filterLogic: '',
            conditions: []
        };
        this.rules = this.decorate([...this.rules, rule]);
    }

    removeRule(event) {
        const idx = parseInt(event.target.dataset.rule, 10);
        const rules = [...this.rules];
        rules.splice(idx, 1);
        // renumber order to stay 1-based and contiguous
        rules.forEach((r, i) => { r.order = i + 1; });
        this.rules = this.decorate(rules);
    }

    addCondition(event) {
        const ri = parseInt(event.target.dataset.rule, 10);
        const rules = [...this.rules];
        rules[ri].conditions = [...rules[ri].conditions, { fieldName: '', operator: 'equals', value: '' }];
        this.rules = this.decorate(rules);
    }

    removeCondition(event) {
        const ri = parseInt(event.target.dataset.rule, 10);
        const ci = parseInt(event.target.dataset.condition, 10);
        const rules = [...this.rules];
        rules[ri].conditions.splice(ci, 1);
        this.rules = this.decorate(rules);
    }

    handleLogicChange(event) {
        const ri = parseInt(event.target.dataset.rule, 10);
        this.rules[ri].filterLogic = event.target.value;
    }

    handleLabelChange(event) {
        const ri = parseInt(event.target.dataset.rule, 10);
        this.rules[ri].label = event.target.value;
    }

    handleFieldChange(event) {
        const ri = parseInt(event.target.dataset.rule, 10);
        const ci = parseInt(event.target.dataset.condition, 10);
        const rules = [...this.rules];
        rules[ri].conditions[ci].fieldName = event.detail.value;
        // re-derive the value input type for the newly chosen field
        const type = this.fieldTypeByName[event.detail.value];
        rules[ri].conditions[ci].inputType = this.inputTypeForFieldType(type);
        rules[ri].conditions[ci].isCheckbox = rules[ri].conditions[ci].inputType === 'checkbox';
        this.rules = rules;
    }

    handleOperatorChange(event) {
        const ri = parseInt(event.target.dataset.rule, 10);
        const ci = parseInt(event.target.dataset.condition, 10);
        this.rules[ri].conditions[ci].operator = event.detail.value;
    }

    handleValueChange(event) {
        const ri = parseInt(event.target.dataset.rule, 10);
        const ci = parseInt(event.target.dataset.condition, 10);
        const cond = this.rules[ri].conditions[ci];
        cond.value = cond.isCheckbox ? String(event.target.checked) : event.target.value;
    }

    handleSave() {
        // strip UI-only keys before sending to Apex
        const payload = this.rules.map((rule) => ({
            id: rule.id,
            label: rule.label,
            objectName: rule.objectName,
            order: rule.order,
            filterLogic: rule.filterLogic,
            conditions: (rule.conditions || []).map((c) => ({
                fieldName: c.fieldName,
                operator: c.operator,
                value: c.value
            }))
        }));
        saveKeepRecordRules({ jsonData: JSON.stringify(payload) })
            .then(() => {
                // success surfaced via the platform-event subscription
            })
            .catch((error) => this.handleError(error));
    }

    // --- platform event + notifications (same pattern as the other settings tabs) ---

    handleSubscribe() {
        const messageCallback = (response) => {
            if (response && response.data && response.data.payload &&
                response.data.payload.IsSuccess__c === true) {
                this.handleSuccess();
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
        this.notificationTitle = 'Keep Record Rules Saved';
        this.notificationStyle = 'success';
        this.notificationBody = '';
        this.showNotification();
        if (this.hasObject) {
            this.loadRules();
        }
    }

    handleError(error) {
        this.notificationTitle = 'An error has occurred';
        this.notificationStyle = 'error';
        this.notificationBody = 'Unknown error';
        if (error && error.body) {
            if (Array.isArray(error.body)) {
                this.notificationBody = error.body.map((e) => e.message).join(', ');
            } else if (typeof error.body.message === 'string') {
                this.notificationBody = error.body.message;
            }
        }
        this.showNotification();
    }

    showNotification() {
        this.dispatchEvent(new ShowToastEvent({
            title: this.notificationTitle,
            message: this.notificationBody,
            variant: this.notificationStyle
        }));
    }
}
