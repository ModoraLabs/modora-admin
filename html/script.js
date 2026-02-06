let isModalOpen = false;
let playerData = null;
let serverConfig = null;
let formData = {
    category: null,
    subject: '',
    description: '',
    priority: 'normal',
    targets: [],
    attachments: [],
    customFields: {}
};

// ============================================
// NUI MESSAGE HANDLING
// ============================================

window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (data.action === 'openReport') {
        openModal();
    } else if (data.action === 'closeReport') {
        closeModal();
    } else if (data.action === 'serverConfig') {
        serverConfig = data.config;
        if (isModalOpen) {
            loadForm();
        }
    } else if (data.action === 'reportSubmitted') {
        handleReportSubmitted(data.success, data.ticketNumber, data.error);
    }
});

// ============================================
// MODAL FUNCTIONS
// ============================================

function openModal() {
    const modal = document.getElementById('reportModal');
    if (!modal) {
        console.error('[Modora] Modal element not found');
        return;
    }
    
    console.log('[Modora] Opening report modal');
    modal.classList.remove('hidden');
    isModalOpen = true;
    
    // Request player data and server config
    requestPlayerData();
    requestServerConfig();
}

function closeModal() {
    const modal = document.getElementById('reportModal');
    if (modal) {
        modal.classList.add('hidden');
    }
    isModalOpen = false;
    
    // Reset form
    formData = {
        category: null,
        subject: '',
        description: '',
        priority: 'normal',
        targets: [],
        attachments: [],
        customFields: {}
    };
    
    // Notify FiveM
    sendNUICallback('closeReport', {}).catch(err => {
        console.error('Failed to notify FiveM of modal close:', err);
    });
}

function GetParentResourceName() {
    return 'modora-reports';
}

// ============================================
// NUI CALLBACKS
// ============================================

function sendNUICallback(callbackName, data) {
    return fetch(`https://${GetParentResourceName()}/${callbackName}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
    })
    .then(response => {
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        return response.json();
    })
    .catch(err => {
        if (err.name !== 'TypeError' || !err.message.includes('Failed to fetch')) {
            console.error(`[Modora] Error calling ${callbackName}:`, err);
        }
        throw err;
    });
}

function requestPlayerData() {
    sendNUICallback('requestPlayerData', {})
        .then(data => {
            if (data && data.success && data.playerData) {
                playerData = data.playerData;
                console.log('[Modora] Player data received:', playerData);
                if (isModalOpen) {
                    loadForm();
                }
            }
        })
        .catch(err => {
            console.error('[Modora] Failed to get player data:', err);
        });
}

function requestServerConfig() {
    sendNUICallback('requestServerConfig', {})
        .then(data => {
            if (data && data.success && data.config) {
                serverConfig = data.config;
                console.log('[Modora] Server config received:', serverConfig);
                if (isModalOpen) {
                    loadForm();
                }
            }
        })
        .catch(err => {
            console.error('[Modora] Failed to get server config:', err);
        });
}

// ============================================
// FORM LOADING
// ============================================

function loadForm() {
    const loadingIndicator = document.getElementById('loadingIndicator');
    const formContent = document.getElementById('formContent');
    const formError = document.getElementById('formError');
    
    if (!playerData) {
        if (loadingIndicator) loadingIndicator.classList.remove('hidden');
        if (formContent) formContent.classList.add('hidden');
        if (formError) {
            formError.classList.add('hidden');
            formError.textContent = '';
        }
        return;
    }
    
    // Hide loading, show form
    if (loadingIndicator) loadingIndicator.classList.add('hidden');
    if (formContent) formContent.classList.remove('hidden');
    if (formError) formError.classList.add('hidden');
    
    // Build form HTML
    const categories = serverConfig?.categories || [
        { id: 'cheat', label: 'Cheating / Modding' },
        { id: 'rdm', label: 'RDM / VDM' },
        { id: 'bug', label: 'Bug / Technical Issue' },
        { id: 'other', label: 'Other' }
    ];
    
    let formHTML = `
        <form id="reportFormElement" class="report-form">
            <div class="form-section">
                <label class="form-label">Category *</label>
                <select id="categorySelect" class="form-select" required>
                    <option value="">Select a category...</option>
                    ${categories.map(cat => `<option value="${cat.id}">${cat.label}</option>`).join('')}
                </select>
            </div>
            
            <div class="form-section">
                <label class="form-label">Subject *</label>
                <input type="text" id="subjectInput" class="form-input" placeholder="Brief description of the issue" required maxlength="255">
            </div>
            
            <div class="form-section">
                <label class="form-label">Description *</label>
                <textarea id="descriptionInput" class="form-textarea" placeholder="Provide detailed information about the issue..." required rows="6"></textarea>
            </div>
            
            <div class="form-section">
                <label class="form-label">Priority</label>
                <select id="prioritySelect" class="form-select">
                    <option value="low">Low</option>
                    <option value="normal" selected>Normal</option>
                    <option value="high">High</option>
                    <option value="urgent">Urgent</option>
                </select>
            </div>
            
            ${playerData.nearbyPlayers && playerData.nearbyPlayers.length > 0 ? `
            <div class="form-section">
                <label class="form-label">Reported Players (Optional)</label>
                <div class="nearby-players">
                    ${playerData.nearbyPlayers.map(player => `
                        <label class="player-checkbox">
                            <input type="checkbox" value="${player.fivemId}" data-player-name="${player.name}">
                            <span>${player.name} (ID: ${player.fivemId}, ${player.distance}m away)</span>
                        </label>
                    `).join('')}
                </div>
            </div>
            ` : ''}
            
            <div class="form-actions">
                <button type="button" class="btn btn-secondary" onclick="closeModal()">Cancel</button>
                <button type="submit" class="btn btn-primary">Submit Report</button>
            </div>
        </form>
    `;
    
    if (formContent) {
        formContent.innerHTML = formHTML;
        
        // Attach event listeners
        const formElement = document.getElementById('reportFormElement');
        if (formElement) {
            formElement.addEventListener('submit', handleFormSubmit);
        }
        
        // Update form data on change
        const categorySelect = document.getElementById('categorySelect');
        const subjectInput = document.getElementById('subjectInput');
        const descriptionInput = document.getElementById('descriptionInput');
        const prioritySelect = document.getElementById('prioritySelect');
        
        if (categorySelect) {
            categorySelect.addEventListener('change', (e) => {
                formData.category = e.target.value;
            });
        }
        
        if (subjectInput) {
            subjectInput.addEventListener('input', (e) => {
                formData.subject = e.target.value;
            });
        }
        
        if (descriptionInput) {
            descriptionInput.addEventListener('input', (e) => {
                formData.description = e.target.value;
            });
        }
        
        if (prioritySelect) {
            prioritySelect.addEventListener('change', (e) => {
                formData.priority = e.target.value;
            });
        }
        
        // Handle nearby players checkboxes
        const checkboxes = formContent.querySelectorAll('input[type="checkbox"]');
        checkboxes.forEach(checkbox => {
            checkbox.addEventListener('change', (e) => {
                if (e.target.checked) {
                    formData.targets.push({
                        fivemId: parseInt(e.target.value),
                        name: e.target.dataset.playerName
                    });
                } else {
                    formData.targets = formData.targets.filter(t => t.fivemId !== parseInt(e.target.value));
                }
            });
        });
    }
}

// ============================================
// FORM SUBMISSION
// ============================================

function handleFormSubmit(e) {
    e.preventDefault();
    
    // Validate form
    if (!formData.category || !formData.subject || !formData.description) {
        showError('Please fill in all required fields');
        return;
    }
    
    // Prepare report data
    const reportData = {
        category: formData.category,
        subject: formData.subject,
        description: formData.description,
        priority: formData.priority,
        reporter: {
            fivemId: playerData.fivemId,
            name: playerData.name,
            identifiers: playerData.identifiers,
            position: playerData.position
        },
        targets: formData.targets,
        attachments: formData.attachments,
        customFields: formData.customFields
    };
    
    console.log('[Modora] Submitting report:', reportData);
    
    // Show loading state
    const submitButton = e.target.querySelector('button[type="submit"]');
    if (submitButton) {
        submitButton.disabled = true;
        submitButton.textContent = 'Submitting...';
    }
    
    // Submit via NUI callback
    sendNUICallback('submitReport', reportData)
        .then(data => {
            if (data && data.success) {
                // Wait for server response via event
                console.log('[Modora] Report submitted, waiting for confirmation...');
            } else {
                showError(data?.error || 'Failed to submit report');
                if (submitButton) {
                    submitButton.disabled = false;
                    submitButton.textContent = 'Submit Report';
                }
            }
        })
        .catch(err => {
            console.error('[Modora] Error submitting report:', err);
            showError('Failed to submit report. Please try again.');
            if (submitButton) {
                submitButton.disabled = false;
                submitButton.textContent = 'Submit Report';
            }
        });
}

function handleReportSubmitted(success, ticketNumber, error) {
    const submitButton = document.querySelector('button[type="submit"]');
    if (submitButton) {
        submitButton.disabled = false;
        submitButton.textContent = 'Submit Report';
    }
    
    if (success) {
        // Show success message
        const formContent = document.getElementById('formContent');
        if (formContent) {
            formContent.innerHTML = `
                <div class="success-message">
                    <div class="success-icon">✓</div>
                    <h3>Report Submitted Successfully!</h3>
                    <p>Your report has been submitted. Ticket ID: <strong>#${ticketNumber}</strong></p>
                    <button class="btn btn-primary" onclick="closeModal()">Close</button>
                </div>
            `;
        }
    } else {
        showError(error || 'Failed to submit report');
    }
}

function showError(message) {
    const formError = document.getElementById('formError');
    if (formError) {
        formError.textContent = message;
        formError.classList.remove('hidden');
    }
}

// ============================================
// ESC KEY HANDLING
// ============================================

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && isModalOpen) {
        closeModal();
    }
});
