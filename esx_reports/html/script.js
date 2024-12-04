// Virtual scrolling configuration
const VIRTUAL_SCROLL_CONFIG = {
    itemHeight: 150, // Approximate height of each report item
    bufferSize: 3,   // Number of items to render above/below viewport
    visibleItems: 10 // Number of items visible at once
};

// Error handling wrapper
function safeExecute(fn) {
    try {
        return fn();
    } catch (error) {
        console.error('[Reports System]:', error);
        return null;
    }
}

// Smooth animation helper using requestAnimationFrame
function smoothAnimate(element, duration, properties) {
    const start = performance.now();
    const initialState = {};
    
    Object.keys(properties).forEach(prop => {
        initialState[prop] = parseFloat(getComputedStyle(element)[prop]) || 0;
    });
    
    const animate = (currentTime) => {
        const elapsed = currentTime - start;
        const progress = Math.min(elapsed / duration, 1);
        const easing = 1 - Math.pow(1 - progress, 3); // Cubic ease-out
        
        Object.keys(properties).forEach(prop => {
            const value = initialState[prop] + (properties[prop] - initialState[prop]) * easing;
            element.style[prop] = prop === 'opacity' ? value : `${value}px`;
        });
        
        if (progress < 1) requestAnimationFrame(animate);
    };
    
    requestAnimationFrame(animate);
}

window.addEventListener('message', function(event) {
    const menu = document.getElementById('reportMenu');
    if (!menu) return;

    switch(event.data.type) {
        case 'openReportMenu':
            document.getElementById('newReportForm').style.display = 'block';
            document.getElementById('reportsList').style.display = 'none';
            menu.style.display = 'block';
            
            const descriptionInput = document.getElementById('reportDescription');
            if (descriptionInput) {
                descriptionInput.maxLength = event.data.maxLength || 1000;
                
                // Remove existing counter if any
                const existingCounter = document.querySelector('.char-counter');
                if (existingCounter) {
                    existingCounter.remove();
                }
                
                // Add character counter
                const counter = document.createElement('div');
                counter.className = 'char-counter';
                counter.style.color = 'rgba(255, 255, 255, 0.7)';
                counter.style.fontSize = '12px';
                counter.style.marginTop = '5px';
                counter.style.textAlign = 'right';
                
                descriptionInput.parentNode.insertBefore(counter, descriptionInput.nextSibling);
                
                // Remove existing listeners
                const newInput = descriptionInput.cloneNode(true);
                descriptionInput.parentNode.replaceChild(newInput, descriptionInput);
                
                // Add new input listener
                newInput.addEventListener('input', function() {
                    const remaining = event.data.maxLength - this.value.length;
                    counter.textContent = `${remaining} characters remaining`;
                    counter.style.color = remaining < 100 ? 'rgba(255, 160, 0, 0.8)' : 'rgba(255, 255, 255, 0.7)';
                });
                
                // Initial counter update
                counter.textContent = `${event.data.maxLength} characters remaining`;
            }
            break;
        case 'showReportsList':
            document.getElementById('newReportForm').style.display = 'none';
            document.getElementById('reportsList').style.display = 'block';
            menu.style.display = 'block';
            showAdminMenu(event.data.reports);
            break;
        case 'statusUpdated':
            updateReportStatusUI(event.data.reportId, event.data.status);
            break;
        case 'closeMenu':
            menu.style.display = 'none';
            break;
    }
});

function submitReport() {
    const reason = document.getElementById('reportReason').value;
    const description = document.getElementById('reportDescription').value;

    if (!reason || !description) {
        // TODO: Add error notification
        return;
    }

    fetch(`https://${GetParentResourceName()}/submitReport`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            reason: reason,
            description: description
        })
    });

    closeMenu();
}

function showAdminMenu(reports) {
    return safeExecute(() => {
        const reportsList = document.getElementById('reportsList');
        reportsList.innerHTML = '';

        if (!reports?.length) {
            reportsList.innerHTML = `
                <div class="empty-reports">
                    <div class="empty-message">
                        <span>No reports available</span>
                        <span class="empty-subtitle">New reports will appear here</span>
                    </div>
                </div>`;
            return;
        }

        // Virtual scrolling state
        let currentRange = {
            start: 0,
            end: VIRTUAL_SCROLL_CONFIG.visibleItems
        };

        function renderVisibleItems() {
            const scrollTop = reportsList.scrollTop;
            const viewportHeight = reportsList.clientHeight;
            
            const startIndex = Math.max(0, 
                Math.floor(scrollTop / VIRTUAL_SCROLL_CONFIG.itemHeight) - VIRTUAL_SCROLL_CONFIG.bufferSize
            );
            const endIndex = Math.min(
                reports.length,
                Math.ceil((scrollTop + viewportHeight) / VIRTUAL_SCROLL_CONFIG.itemHeight) + VIRTUAL_SCROLL_CONFIG.bufferSize
            );

            if (startIndex !== currentRange.start || endIndex !== currentRange.end) {
                currentRange = { start: startIndex, end: endIndex };
                
                const topSpace = startIndex * VIRTUAL_SCROLL_CONFIG.itemHeight;
                const bottomSpace = (reports.length - endIndex) * VIRTUAL_SCROLL_CONFIG.itemHeight;
                
                reportsList.innerHTML = `
                    <div style="height: ${topSpace}px"></div>
                    ${reports.slice(startIndex, endIndex).map(createReportElement).join('')}
                    <div style="height: ${bottomSpace}px"></div>
                `;
            }
        }

        // Optimized scroll handler with throttling
        let scrollTimeout;
        reportsList.addEventListener('scroll', () => {
            if (!scrollTimeout) {
                scrollTimeout = setTimeout(() => {
                    renderVisibleItems();
                    scrollTimeout = null;
                }, 16); // ~60fps
            }
        });

        // Initial render
        renderVisibleItems();
    });
}

function createReportElement(report) {
    return `
        <div class="report-item" data-id="${report.id}">
            <div class="report-header">
                <div class="report-info">
                    <span class="report-status status-${report.status || 'pending'}">${report.status || 'pending'}</span>
                    <span class="report-player">${report.reporterName || 'Unknown'} (#${report.reporterId || 'System'})</span>
                </div>
            </div>
            <div class="report-content">
                <div class="report-section">
                    <span class="report-label">Reason:</span>
                    <div class="report-reason">${report.reason || 'No reason provided'}</div>
                </div>
                <div class="report-section">
                    <span class="report-label">Description:</span>
                    <div class="report-description">${report.description || 'No description provided'}</div>
                </div>
            </div>
            <div class="report-actions">
                ${report.status === 'pending' ? 
                    `<button class="btn-take" onclick="updateReportStatus(${report.id}, 'inprogress')">Take</button>` : ''}
                ${report.status === 'inprogress' ? 
                    `<button class="btn-resolve" onclick="updateReportStatus(${report.id}, 'resolved')">Resolve</button>` : ''}
                <button class="btn-delete" onclick="deleteReport(${report.id})">Delete</button>
            </div>
        </div>
    `;
}

function updateReportStatus(reportId, newStatus) {
    // Update UI immediately
    updateReportStatusUI(reportId, newStatus);

    // Then send to server
    fetch(`https://${GetParentResourceName()}/updateStatus`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            reportId: reportId,
            status: newStatus
        })
    });
}

function updateReportStatusUI(reportId, newStatus) {
    const reportElement = document.querySelector(`.report-item[data-id="${reportId}"]`);
    if (!reportElement) return;

    const statusElement = reportElement.querySelector('.report-status');
    if (!statusElement) return;

    // Update status immediately
    statusElement.className = `report-status status-${newStatus}`;
    statusElement.innerHTML = `${newStatus}`;

    // Update buttons immediately
    const actionsDiv = reportElement.querySelector('.report-actions');
    if (actionsDiv) {
        const buttons = actionsDiv.innerHTML;
        if (newStatus === 'inprogress') {
            actionsDiv.innerHTML = `
                <button class="btn-resolve" onclick="updateReportStatus(${reportId}, 'resolved')">Resolve</button>
                <button class="btn-delete" onclick="deleteReport(${reportId})">Delete</button>
            `;
        } else if (newStatus === 'resolved') {
            actionsDiv.innerHTML = `
                <button class="btn-delete" onclick="deleteReport(${reportId})">Delete</button>
            `;
        }
    }
}

function deleteReport(reportId) {
    return safeExecute(() => {
        const reportElement = document.querySelector(`.report-item[data-id="${reportId}"]`);
        if (!reportElement) return;

        const deleteBtn = reportElement.querySelector('.btn-delete');
        if (deleteBtn?.classList.contains('confirming')) {
            fetch(`https://${GetParentResourceName()}/deleteReport`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ reportId })
            });
            
            smoothAnimate(reportElement, 200, {
                opacity: 0,
                transform: 0.9
            });

            setTimeout(() => {
                reportElement.remove();
                checkEmptyReports();
            }, 200);
        } else if (deleteBtn) {
            deleteBtn.classList.add('confirming');
            deleteBtn.textContent = 'Confirm';
            
            setTimeout(() => {
                if (deleteBtn?.classList.contains('confirming')) {
                    deleteBtn.classList.remove('confirming');
                    deleteBtn.textContent = 'Delete';
                }
            }, 3000);
        }
    });
}

function checkEmptyReports() {
    const reportsList = document.getElementById('reportsList');
    if (!reportsList.querySelector('.report-item')) {
        const emptyMessage = document.createElement('div');
        emptyMessage.className = 'empty-reports';
        emptyMessage.innerHTML = `
            <div class="empty-message">
                <span>No reports available</span>
                <span class="empty-subtitle">New reports will appear here</span>
            </div>
        `;
        reportsList.appendChild(emptyMessage);
    }
}

function closeMenu() {
    const menu = document.getElementById('reportMenu');
    if (menu) {
        menu.style.display = 'none';
    }
    
    const reasonInput = document.getElementById('reportReason');
    const descriptionInput = document.getElementById('reportDescription');
    
    if (reasonInput) reasonInput.value = '';
    if (descriptionInput) descriptionInput.value = '';

    fetch(`https://${GetParentResourceName()}/closeMenu`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
}

// Close menu when pressing ESC
document.onkeyup = function(data) {
    if (data.key === 'Escape') {
        closeMenu();
    }
};

// Add event listener for submit button
document.addEventListener('DOMContentLoaded', function() {
    const submitButton = document.getElementById('submitReport');
    if (submitButton) {
        submitButton.addEventListener('click', submitReport);
    }
});
