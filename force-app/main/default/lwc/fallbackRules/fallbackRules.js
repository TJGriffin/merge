import { LightningElement, track, wire } from 'lwc';
import { subscribe, onError } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFallbackRules from '@salesforce/apex/MRG_FallbackRules_CTRL.getFallbackRules';
import getObjectFields from '@salesforce/apex/MRG_FallbackRules_CTRL.getObjectFields';
import getOperators from '@salesforce/apex/MRG_FallbackRules_CTRL.getOperators';
import saveFallbackRules from '@salesforce/apex/MRG_FallbackRules_CTRL.saveFallbackRules';

export default class FallbackRules extends LightningElement {
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
    selectionOptions = [
        { label: 'Simple (by record age)', value: 'simple' },
        { label: 'Complex (conditions + tie-break)', value: 'complex' }
    ];
    ruleOptions = [
        { label: 'Newest record', value: 'Newest' },
        { label: 'Oldest record', value: 'Oldest' }
    ];
    directionOptions = [
        { label: 'Descending', value: 'DESC' },
        { label: 'Ascending', value: 'ASC' }
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
                this.rules = this.decorate(this.rules);
            })
            .catch((error) => this.handleError(error));
    }

    loadRules() {
        getFallbackRules({ objectType: this.objectType })
            .then((result) => {
                this.rules = this.decorate(JSON.parse(JSON.stringify(result)));
            })
            .catch((error) => this.handleError(error));
    }

    decorate(rules) {
        return (rules || []).map((rule, ri) => {
            rule.uiKey = 'fb-' + ri + '-' + Date.now();
            rule.ruleIndex = ri;
            rule.isComplex = rule.selectionType === 'complex';
            rule.conditions = (rule.conditions || []).map((c, ci) => this.decorateCondition(c, ri, ci));
            rule.fieldPairs = (rule.fieldPairs || []).map((p, pi) => {
                p.ruleIndex = ri;
                p.pairIndex = pi;
                p.uiKey = 'pair-' + ri + '-' + pi;
                return p;
            });
            return rule;
        });
    }

    decorateCondition(condition, ri, ci) {
        condition.uiKey = 'cond-' + ri + '-' + ci;
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
            case 'DATETIME': return 'datetime';
            case 'DOUBLE':
            case 'CURRENCY':
            case 'INTEGER':
            case 'LONG':
            case 'PERCENT': return 'number';
            default: return 'text';
        }
    }

    addRule() {
        const rule = {
            id: null,
            label: this.objectType + ' Fallback ' + (this.rules.length + 1),
            objectName: this.objectType,
            selectionType: 'simple',
            rule: 'Newest',
            filterLogic: '',
            conditions: [],
            tieBreakField: null,
            tieBreakDirection: 'DESC',
            fieldPairs: []
        };
        this.rules = this.decorate([...this.rules, rule]);
    }

    removeRule(event) {
        const idx = parseInt(event.target.dataset.rule, 10);
        const rules = [...this.rules];
        rules.splice(idx, 1);
        this.rules = this.decorate(rules);
    }

    handleLabelChange(event) {
        this.rules[parseInt(event.target.dataset.rule, 10)].label = event.target.value;
    }

    handleSelectionTypeChange(event) {
        const ri = parseInt(event.target.dataset.rule, 10);
        this.rules[ri].selectionType = event.detail.value;
        this.rules = this.decorate(this.rules);
    }

    handleSimpleRuleChange(event) {
        this.rules[parseInt(event.target.dataset.rule, 10)].rule = event.detail.value;
    }

    handleLogicChange(event) {
        this.rules[parseInt(event.target.dataset.rule, 10)].filterLogic = event.target.value;
    }

    handleTieBreakFieldChange(event) {
        this.rules[parseInt(event.target.dataset.rule, 10)].tieBreakField = event.detail.value;
    }

    handleTieBreakDirectionChange(event) {
        this.rules[parseInt(event.target.dataset.rule, 10)].tieBreakDirection = event.detail.value;
    }

    // --- conditions ---
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

    handleConditionFieldChange(event) {
        const ri = parseInt(event.target.dataset.rule, 10);
        const ci = parseInt(event.target.dataset.condition, 10);
        const rules = [...this.rules];
        rules[ri].conditions[ci].fieldName = event.detail.value;
        this.rules = this.decorate(rules);
    }

    handleConditionOperatorChange(event) {
        const ri = parseInt(event.target.dataset.rule, 10);
        const ci = parseInt(event.target.dataset.condition, 10);
        this.rules[ri].conditions[ci].operator = event.detail.value;
    }

    handleConditionValueChange(event) {
        const ri = parseInt(event.target.dataset.rule, 10);
        const ci = parseInt(event.target.dataset.condition, 10);
        const cond = this.rules[ri].conditions[ci];
        cond.value = cond.isCheckbox ? String(event.target.checked) : event.target.value;
    }

    // --- field pairs ---
    addPair(event) {
        const ri = parseInt(event.target.dataset.rule, 10);
        const rules = [...this.rules];
        rules[ri].fieldPairs = [...rules[ri].fieldPairs, { sourceField: '', targetField: '' }];
        this.rules = this.decorate(rules);
    }

    removePair(event) {
        const ri = parseInt(event.target.dataset.rule, 10);
        const pi = parseInt(event.target.dataset.pair, 10);
        const rules = [...this.rules];
        rules[ri].fieldPairs.splice(pi, 1);
        this.rules = this.decorate(rules);
    }

    handlePairSourceChange(event) {
        const ri = parseInt(event.target.dataset.rule, 10);
        const pi = parseInt(event.target.dataset.pair, 10);
        this.rules[ri].fieldPairs[pi].sourceField = event.detail.value;
    }

    handlePairTargetChange(event) {
        const ri = parseInt(event.target.dataset.rule, 10);
        const pi = parseInt(event.target.dataset.pair, 10);
        this.rules[ri].fieldPairs[pi].targetField = event.detail.value;
    }

    handleSave() {
        const payload = this.rules.map((rule) => ({
            id: rule.id,
            label: rule.label,
            objectName: rule.objectName,
            selectionType: rule.selectionType,
            rule: rule.rule,
            filterLogic: rule.filterLogic,
            conditions: (rule.conditions || []).map((c) => ({ fieldName: c.fieldName, operator: c.operator, value: c.value })),
            tieBreakField: rule.tieBreakField,
            tieBreakDirection: rule.tieBreakDirection,
            fieldPairs: (rule.fieldPairs || []).map((p) => ({ sourceField: p.sourceField, targetField: p.targetField }))
        }));
        saveFallbackRules({ jsonData: JSON.stringify(payload) })
            .then(() => {})
            .catch((error) => this.handleError(error));
    }

    // --- platform event + notifications ---
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
        this.notificationTitle = 'Fallback Rules Saved';
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
