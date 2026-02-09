(function() {
    'use strict';

    var RESOURCE_NAME = 'modora-admin';

    function getParentResourceName() {
        if (typeof GetParentResourceName === 'function') {
            return GetParentResourceName();
        }
        return RESOURCE_NAME;
    }

    var state = {
        view: 'closed', // closed | loading | form | submitting | success | error
        init: null,     // { serverName, cooldownRemaining, playerName, theme, version }
        playerData: null,
        serverConfig: null,
        form: {
            category: '',
            subject: '',
            description: '',
            evidenceUrls: [],
            targets: []
        },
        cooldownRemaining: 0,
        lastSuccess: null  // { ticketId, ticketNumber, ticketUrl }
    };

    var DEFAULT_CATEGORIES = [
        { id: 'scam', label: 'Scam' },
        { id: 'harassment', label: 'Harassment' },
        { id: 'exploit', label: 'Exploit' },
        { id: 'cheating', label: 'Cheating' },
        { id: 'other', label: 'Other' }
    ];

    function escapeText(str) {
        if (str == null || typeof str !== 'string') return '';
        var div = document.createElement('div');
        div.textContent = str;
        return div.innerHTML;
    }

    function showView(viewName) {
        state.view = viewName;
        var app = document.getElementById('app');
        var loading = document.getElementById('stateLoading');
        var form = document.getElementById('stateForm');
        var success = document.getElementById('stateSuccess');

        if (!app) return;
        app.classList.remove('hidden');

        if (loading) loading.classList.add('hidden');
        if (form) form.classList.add('hidden');
        if (success) success.classList.add('hidden');

        switch (viewName) {
            case 'loading':
                if (loading) loading.classList.remove('hidden');
                break;
            case 'form':
            case 'submitting':
                if (form) form.classList.remove('hidden');
                var btn = document.getElementById('btnSubmit');
                if (btn) btn.disabled = (viewName === 'submitting');
                break;
            case 'success':
            case 'error':
                if (success) success.classList.remove('hidden');
                break;
            case 'closed':
                app.classList.add('hidden');
                break;
        }
    }

    function sendNuiCallback(name, data) {
        data = data || {};
        return fetch('https://' + getParentResourceName() + '/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        }).then(function(res) {
            if (!res.ok) throw new Error('HTTP ' + res.status);
            return res.json();
        });
    }

    function requestPlayerData() {
        return sendNuiCallback('requestPlayerData', {}).then(function(data) {
            if (data && data.success && data.playerData) {
                state.playerData = data.playerData;
                return state.playerData;
            }
            throw new Error('No player data');
        });
    }

    function requestServerConfig() {
        return sendNuiCallback('requestServerConfig', {}).then(function(data) {
            if (data && data.success && data.config) {
                state.serverConfig = data.config;
                return state.serverConfig;
            }
            return null;
        });
    }

    function renderCategories() {
        var rfc = state.serverConfig && state.serverConfig.reportFormConfig;
        var categories = (rfc && rfc.categories && rfc.categories.length) ? rfc.categories.map(function(c) {
            return { id: c.id, label: c.label || c.id };
        }) : (state.serverConfig && state.serverConfig.categories) || DEFAULT_CATEGORIES;
        var select = document.getElementById('category');
        if (!select) return;
        var first = select.querySelector('option');
        select.innerHTML = first ? first.outerHTML : '<option value="">Select category...</option>';
        categories.forEach(function(cat) {
            var id = typeof cat === 'object' ? (cat.id || cat.value) : cat;
            var label = typeof cat === 'object' ? (cat.label || cat.name || id) : id;
            var opt = document.createElement('option');
            opt.value = id;
            opt.textContent = label;
            select.appendChild(opt);
        });
    }

    function renderIntroText() {
        var rfc = state.serverConfig && state.serverConfig.reportFormConfig;
        var intro = (rfc && rfc.introText) ? String(rfc.introText).trim() : '';
        var el = document.getElementById('reportIntroText');
        if (!el) return;
        if (intro) {
            el.textContent = intro;
            el.classList.remove('hidden');
        } else {
            el.classList.add('hidden');
        }
    }

    function renderEvidenceUrls() {
        var list = document.getElementById('evidenceList');
        if (!list) return;
        list.innerHTML = '';
        state.form.evidenceUrls.forEach(function(url, i) {
            var item = document.createElement('div');
            item.className = 'modora-evidence-item';
            var input = document.createElement('input');
            input.type = 'url';
            input.placeholder = 'https://...';
            input.className = 'modora-input';
            input.value = url;
            input.setAttribute('data-index', i);
            input.addEventListener('input', function() {
                state.form.evidenceUrls[parseInt(this.getAttribute('data-index'), 10)] = this.value;
            });
            var btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'modora-btn modora-btn-ghost';
            btn.textContent = 'Remove';
            btn.addEventListener('click', function() {
                state.form.evidenceUrls.splice(i, 1);
                renderEvidenceUrls();
            });
            item.appendChild(input);
            item.appendChild(btn);
            list.appendChild(item);
        });
    }

    function addEvidenceUrl() {
        state.form.evidenceUrls.push('');
        renderEvidenceUrls();
    }

    function renderNearbyPlayers() {
        var section = document.getElementById('nearbySection');
        var container = document.getElementById('nearbyPlayers');
        if (!section || !container) return;
        var players = (state.playerData && state.playerData.nearbyPlayers) || [];
        if (players.length === 0) {
            section.classList.add('hidden');
            return;
        }
        section.classList.remove('hidden');
        container.innerHTML = '';
        state.form.targets = [];
        players.forEach(function(p) {
            var label = document.createElement('label');
            label.className = 'modora-player-checkbox';
            var cb = document.createElement('input');
            cb.type = 'checkbox';
            cb.value = p.fivemId;
            cb.setAttribute('data-name', p.name || '');
            cb.addEventListener('change', function() {
                if (this.checked) {
                    state.form.targets.push({ fivemId: parseInt(this.value, 10), name: this.getAttribute('data-name') || '' });
                } else {
                    state.form.targets = state.form.targets.filter(function(t) { return t.fivemId !== parseInt(this.value, 10); }.bind(this));
                }
            });
            label.appendChild(cb);
            var span = document.createElement('span');
            span.textContent = (p.name || 'Player') + ' (ID: ' + p.fivemId + (p.distance != null ? ', ' + p.distance + 'm' : '') + ')';
            label.appendChild(span);
            container.appendChild(label);
        });
    }

    function updateCharCounts() {
        var sub = document.getElementById('subject');
        var desc = document.getElementById('description');
        var subCount = document.getElementById('subjectCount');
        var descCount = document.getElementById('descriptionCount');
        if (sub && subCount) subCount.textContent = (sub.value || '').length;
        if (desc && descCount) descCount.textContent = (desc.value || '').length;
    }

    function validateForm() {
        var category = (document.getElementById('category') && document.getElementById('category').value) || '';
        var subject = (document.getElementById('subject') && document.getElementById('subject').value) || '';
        var description = (document.getElementById('description') && document.getElementById('description').value) || '';

        var errors = {};
        if (!category) errors.category = 'Select a category';
        if (!subject || subject.length < 1) errors.subject = 'Title is required';
        else if (subject.length > 80) errors.subject = 'Title must be 80 characters or less';
        if (!description || description.length < 20) errors.description = 'Description must be at least 20 characters';
        else if (description.length > 2000) errors.description = 'Description must be 2000 characters or less';

        ['category', 'subject', 'description'].forEach(function(field) {
            var errEl = document.getElementById(field + 'Error');
            if (errEl) {
                errEl.textContent = errors[field] || '';
                errEl.classList.toggle('hidden', !errors[field]);
            }
        });
        var formError = document.getElementById('formError');
        if (formError) {
            formError.textContent = Object.keys(errors).length ? (errors.category || errors.subject || errors.description) : '';
            formError.classList.toggle('hidden', !formError.textContent);
        }
        return Object.keys(errors).length === 0;
    }

    function submitReport() {
        if (!state.playerData) return;
        if (!validateForm()) return;

        var categoryEl = document.getElementById('category');
        var subjectEl = document.getElementById('subject');
        var descriptionEl = document.getElementById('description');

        var reportData = {
            category: categoryEl ? categoryEl.value : '',
            subject: subjectEl ? subjectEl.value.trim() : '',
            description: descriptionEl ? descriptionEl.value.trim() : '',
            priority: 'normal',
            reporter: {
                fivemId: state.playerData.fivemId,
                name: state.playerData.name,
                identifiers: state.playerData.identifiers || {},
                position: state.playerData.position || null
            },
            targets: state.form.targets,
            attachments: [],
            customFields: {},
            evidenceUrls: state.form.evidenceUrls.filter(Boolean)
        };

        showView('submitting');

        sendNuiCallback('submitReport', reportData).then(function(data) {
            if (data && data.success) {
                // Wait for reportSubmitted event from Lua for final result
            } else {
                showView('form');
                var formError = document.getElementById('formError');
                if (formError) {
                    formError.textContent = (data && data.error) || 'Submit failed';
                    formError.classList.remove('hidden');
                }
                var btn = document.getElementById('btnSubmit');
                if (btn) btn.disabled = false;
            }
        }).catch(function(err) {
            showView('form');
            var formError = document.getElementById('formError');
            if (formError) {
                formError.textContent = 'Failed to send report. Try again.';
                formError.classList.remove('hidden');
            }
            var btn = document.getElementById('btnSubmit');
            if (btn) btn.disabled = false;
        });
    }

    function handleReportSubmitted(payload) {
        var success = payload && payload.success;
        var ticketNumber = payload && payload.ticketNumber;
        var ticketId = payload && payload.ticketId;
        var ticketUrl = payload && payload.ticketUrl;
        var error = payload && payload.error;
        var cooldownSeconds = payload && payload.cooldownSeconds;

        var btn = document.getElementById('btnSubmit');
        if (btn) btn.disabled = false;

        if (success) {
            state.lastSuccess = { ticketId: ticketId, ticketNumber: ticketNumber, ticketUrl: ticketUrl };
            var msg = document.getElementById('successMessage');
            if (msg) {
                if (ticketNumber != null) {
                    msg.textContent = 'Your report was submitted. Ticket #' + escapeText(String(ticketNumber));
                } else {
                    msg.textContent = 'Your report was submitted successfully.';
                }
            }
            var link = document.getElementById('ticketLink');
            if (link && ticketUrl) {
                link.href = ticketUrl;
                link.classList.remove('hidden');
            } else if (link) {
                link.classList.add('hidden');
            }
            showView('success');
        } else {
            showView('form');
            var formError = document.getElementById('formError');
            if (formError) {
                formError.textContent = escapeText(error || 'Report could not be sent.');
                formError.classList.remove('hidden');
            }
            if (cooldownSeconds != null && cooldownSeconds > 0) {
                state.cooldownRemaining = cooldownSeconds;
                var notice = document.getElementById('cooldownNotice');
                if (notice) {
                    notice.textContent = 'You can report again in ' + cooldownSeconds + ' seconds.';
                    notice.classList.remove('hidden');
                }
            }
        }
    }

    function openReport() {
        showView('loading');
        state.form = { category: '', subject: '', description: '', evidenceUrls: [], targets: [] };
        state.lastSuccess = null;

        var serverNameEl = document.getElementById('serverName');
        if (serverNameEl && state.init && state.init.serverName) {
            serverNameEl.textContent = escapeText(state.init.serverName);
        } else if (serverNameEl) {
            serverNameEl.textContent = '';
        }

        Promise.all([requestPlayerData(), requestServerConfig()]).then(function() {
            renderCategories();
            renderIntroText();
            renderEvidenceUrls();
            renderNearbyPlayers();
            var categoryEl = document.getElementById('category');
            var subjectEl = document.getElementById('subject');
            var descriptionEl = document.getElementById('description');
            if (categoryEl) categoryEl.value = state.form.category || '';
            if (subjectEl) subjectEl.value = state.form.subject || '';
            if (descriptionEl) descriptionEl.value = state.form.description || '';
            updateCharCounts();
            var formError = document.getElementById('formError');
            var cooldownNotice = document.getElementById('cooldownNotice');
            if (formError) { formError.classList.add('hidden'); formError.textContent = ''; }
            if (cooldownNotice) cooldownNotice.classList.add('hidden');
            showView('form');
        }).catch(function() {
            var formError = document.getElementById('formError');
            if (formError) {
                formError.textContent = 'Could not load form. Try again.';
                formError.classList.remove('hidden');
            }
            showView('form');
        });
    }

    function closeReport() {
        showView('closed');
        sendNuiCallback('closeReport', {}).catch(function() {});
    }

    function bindUi() {
        var app = document.getElementById('app');
        var backdrop = app && app.querySelector('[data-action="close"]');
        if (backdrop) backdrop.addEventListener('click', closeReport);

        var btnClose = document.getElementById('btnClose');
        if (btnClose) btnClose.addEventListener('click', closeReport);

        var btnCancel = document.getElementById('btnCancel');
        if (btnCancel) btnCancel.addEventListener('click', closeReport);

        var btnCloseSuccess = document.getElementById('btnCloseSuccess');
        if (btnCloseSuccess) btnCloseSuccess.addEventListener('click', closeReport);

        var btnAddEvidence = document.getElementById('btnAddEvidence');
        if (btnAddEvidence) btnAddEvidence.addEventListener('click', addEvidenceUrl);

        var btnTakeScreenshot = document.getElementById('btnTakeScreenshot');
        if (btnTakeScreenshot) {
            btnTakeScreenshot.addEventListener('click', function() {
                var btn = this;
                btn.disabled = true;
                btn.textContent = 'Taking screenshot...';
                sendNuiCallback('requestScreenshotUpload', {}).then(function(data) {
                    btn.disabled = false;
                    btn.textContent = '📷 Take screenshot';
                    if (data && data.success && data.url) {
                        state.form.evidenceUrls.push(data.url);
                        renderEvidenceUrls();
                    } else if (data && data.error) {
                        var formError = document.getElementById('formError');
                        if (formError) {
                            formError.textContent = data.error;
                            formError.classList.remove('hidden');
                        }
                    }
                }).catch(function() {
                    btn.disabled = false;
                    btn.textContent = '📷 Take screenshot';
                });
            });
        }

        var form = document.getElementById('reportForm');
        if (form) {
            form.addEventListener('submit', function(e) {
                e.preventDefault();
                submitReport();
            });
        }

        var subjectEl = document.getElementById('subject');
        var descriptionEl = document.getElementById('description');
        if (subjectEl) subjectEl.addEventListener('input', updateCharCounts);
        if (descriptionEl) descriptionEl.addEventListener('input', updateCharCounts);
    }

    window.addEventListener('message', function(event) {
        var data = event.data;
        if (data.type === 'INIT') {
            state.init = {
                serverName: data.serverName,
                cooldownRemaining: data.cooldownRemaining,
                playerName: data.playerName,
                theme: data.theme,
                version: data.version
            };
        }
        if (data.action === 'openReport') {
            if (data.type === 'INIT') {
                state.init = state.init || {};
                state.init.serverName = data.serverName || state.init.serverName;
                state.init.cooldownRemaining = data.cooldownRemaining != null ? data.cooldownRemaining : state.init.cooldownRemaining;
                state.init.playerName = data.playerName || state.init.playerName;
            }
            openReport();
        } else if (data.action === 'closeReport') {
            closeReport();
        } else if (data.action === 'reportSubmitted') {
            handleReportSubmitted(data);
        } else if (data.action === 'screenshotReady' && data.url) {
            state.form.evidenceUrls.push(data.url);
            renderEvidenceUrls();
        }
    });

    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' && state.view !== 'closed') {
            closeReport();
        }
    });

    document.addEventListener('DOMContentLoaded', bindUi);
})();
