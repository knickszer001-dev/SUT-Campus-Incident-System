/* ==========================================================================
   SCRIPT ENGINE: SUT Campus Incident System Showcase Web App
   Handles SPA routes, collapsible menus, Search filters, and dynamic Charts
   ========================================================================== */

document.addEventListener('DOMContentLoaded', () => {
    // --- Initial Config & Theme Setup ---
    initTheme();
    initScrollProgressBar();
    initSPA();
    initAccordions();
    initTabs();
    initModals();
    initSearch();
    initCharts();
    initCopyCode();
    initAnimateCounters();

    // --- Sidebar Menu Toggle (Mobile) ---
    const menuToggleBtn = document.getElementById('menuToggleBtn');
    const sidebar = document.getElementById('sidebar');

    if (menuToggleBtn && sidebar) {
        menuToggleBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            sidebar.classList.toggle('active');
        });

        // Close sidebar when clicking outside on mobile
        document.addEventListener('click', (e) => {
            if (window.innerWidth <= 768 && sidebar.classList.contains('active') && !sidebar.contains(e.target)) {
                sidebar.classList.remove('active');
            }
        });
    }
});

/* ==========================================
   1. THEME CONTROLLER (Dark / Light Mode)
   ========================================== */
function initTheme() {
    const themeBtn = document.getElementById('themeBtn');
    if (!themeBtn) return;

    // Check localStorage or browser preference
    const savedTheme = localStorage.getItem('theme') || 
                       (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    
    document.documentElement.setAttribute('data-theme', savedTheme);
    updateThemeIcon(savedTheme);

    themeBtn.addEventListener('click', () => {
        const currentTheme = document.documentElement.getAttribute('data-theme');
        const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
        
        document.documentElement.setAttribute('data-theme', newTheme);
        localStorage.setItem('theme', newTheme);
        updateThemeIcon(newTheme);
    });
}

function updateThemeIcon(theme) {
    const themeIcon = document.getElementById('themeIcon');
    if (!themeIcon) return;
    themeIcon.textContent = theme === 'dark' ? '☀️' : '🌙';
}

/* ==========================================
   2. SCROLL PROGRESS INDICATOR
   ========================================== */
function initScrollProgressBar() {
    const contentPanel = document.getElementById('contentPanel') || document.querySelector('.main-content');
    const scrollBar = document.getElementById('scrollBar');
    if (!contentPanel || !scrollBar) return;

    contentPanel.addEventListener('scroll', () => {
        const scrollTop = contentPanel.scrollTop;
        const scrollHeight = contentPanel.scrollHeight - contentPanel.clientHeight;
        const scrollPercent = scrollHeight > 0 ? (scrollTop / scrollHeight) * 100 : 0;
        scrollBar.style.width = scrollPercent + '%';
    });
}

/* ==========================================
   3. SINGLE PAGE APP NAVIGATION
   ========================================== */
function initSPA() {
    const navLinks = document.querySelectorAll('.nav-link');
    const sections = document.querySelectorAll('.module-section');
    const contentPanel = document.getElementById('contentPanel') || document.querySelector('.main-content');
    const sidebar = document.getElementById('sidebar');

    navLinks.forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const targetId = link.getAttribute('data-target');
            if (!targetId) return;

            // Update active link
            navLinks.forEach(l => l.classList.remove('active'));
            link.classList.add('active');

            // Update active section
            sections.forEach(sec => sec.classList.remove('active'));
            const targetSec = document.getElementById(targetId);
            if (targetSec) {
                targetSec.classList.add('active');
            }

            // Scroll content panel to top
            if (contentPanel) {
                contentPanel.scrollTo({ top: 0, behavior: 'smooth' });
            }

            // Close sidebar on mobile
            if (sidebar && window.innerWidth <= 768) {
                sidebar.classList.remove('active');
            }

            // Trigger animations / charts resize
            window.dispatchEvent(new Event('resize'));
        });
    });
}

/* ==========================================
   4. INTERACTIVE ACCORDIONS
   ========================================== */
function initAccordions() {
    document.addEventListener('click', (e) => {
        const header = e.target.closest('.accordion-header');
        if (!header) return;

        const item = header.closest('.accordion-item');
        if (!item) return;

        const body = item.querySelector('.accordion-body');
        if (!body) return;

        // Toggle state
        const isActive = item.classList.contains('active');
        
        if (isActive) {
            item.classList.remove('active');
            body.style.maxHeight = null;
        } else {
            // Close other accordions in the same container if needed, but here we allow multiple open
            item.classList.add('active');
            body.style.maxHeight = body.scrollHeight + "px";
        }
    });
}

/* ==========================================
   5. INTERACTIVE TABS
   ========================================== */
function initTabs() {
    document.addEventListener('click', (e) => {
        const btn = e.target.closest('.tab-btn');
        if (!btn) return;

        const container = btn.closest('.tab-container');
        if (!container) return;

        const targetId = btn.getAttribute('data-tab');
        if (!targetId) return;

        // Deactivate all sibling buttons
        container.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        // Hide all panes
        container.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
        
        // Show target pane
        const targetPane = container.querySelector('#' + targetId);
        if (targetPane) {
            targetPane.classList.add('active');
        }
    });
}

/* ==========================================
   6. SENSEII INTERACTIVE ARCH MODALS
   ========================================== */
function initModals() {
    window.openModal = function(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            modal.classList.add('active');
            document.body.classList.add('modal-open');
        }
    };

    window.closeModal = function(event, modalId) {
        const modal = document.getElementById(modalId);
        if (!modal) return;

        // Close if click on background backdrop or close button
        if (event.target.classList.contains('modal-overlay') || 
            event.target.closest('.modal-close-btn')) {
            modal.classList.remove('active');
            document.body.classList.remove('modal-open');
        }
    };

    document.addEventListener('keydown', (event) => {
        if (event.key !== 'Escape') return;
        document.querySelectorAll('.modal-overlay.active').forEach(modal => modal.classList.remove('active'));
        document.body.classList.remove('modal-open');
    });
}

/* ==========================================
   7. TECHNICAL SEARCH / FILTER SYSTEM
   ========================================== */
function initSearch() {
    const searchInput = document.getElementById('searchInput');
    if (!searchInput) return;

    searchInput.addEventListener('input', () => {
        const query = searchInput.value.toLowerCase().trim();

        // 1. Filter packages in tables
        const tableRows = document.querySelectorAll('.tech-table tbody tr');
        tableRows.forEach(row => {
            const text = row.textContent.toLowerCase();
            if (text.includes(query)) {
                row.style.display = '';
            } else {
                row.style.display = 'none';
            }
        });

        // 2. Filter accordions
        const accItems = document.querySelectorAll('.accordion-item');
        accItems.forEach(item => {
            const headerText = item.querySelector('.accordion-header').textContent.toLowerCase();
            const bodyText = item.querySelector('.accordion-body').textContent.toLowerCase();
            if (headerText.includes(query) || bodyText.includes(query)) {
                item.style.display = '';
            } else {
                item.style.display = 'none';
            }
        });

        // 3. Highlight search items
        const menuItems = document.querySelectorAll('.menu-item');
        menuItems.forEach(item => {
            const text = item.textContent.toLowerCase();
            if (query !== '' && text.includes(query)) {
                item.style.borderLeft = '3px solid hsl(var(--sut-brand))';
            } else {
                item.style.borderLeft = '';
            }
        });
    });
}

/* ==========================================
   8. CHARTS SERVICE (Chart.js Engine)
   ========================================== */
function initCharts() {
    // Check if Chart.js is loaded
    if (typeof Chart === 'undefined') return;

    Chart.defaults.font.family = "'Prompt', sans-serif";
    Chart.defaults.color = 'hsl(var(--text-secondary))';

    // 1. PDF Satisfaction Chart (Bar)
    const ctxSatisfaction = document.getElementById('evalSatisfactionChart');
    if (ctxSatisfaction) {
        new Chart(ctxSatisfaction, {
            type: 'bar',
            data: {
                labels: ['ด้าน UI/UX และการใช้งานระบบ', 'ด้านฟังก์ชันประสานงานกู้ภัย', 'ด้านความปลอดภัยและความรวดเร็ว'],
                datasets: [{
                    label: 'คะแนนการประเมินความพึงพอใจ UAT (เต็ม 5.00)',
                    data: [4.57, 4.55, 4.60],
                    backgroundColor: [
                        'rgba(30, 58, 138, 0.85)',  // Deep Navy
                        'rgba(234, 88, 12, 0.85)',  // Emergency Orange
                        'rgba(16, 185, 129, 0.85)'  // Emerald Green
                    ],
                    borderColor: [
                        'rgba(30, 58, 138, 1)',
                        'rgba(234, 88, 12, 1)',
                        'rgba(16, 185, 129, 1)'
                    ],
                    borderWidth: 1.5,
                    borderRadius: 8,
                    barThickness: 50
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        callbacks: {
                            label: function(context) { return ' คะแนนเฉลี่ย: ' + context.parsed.y.toFixed(2) + ' / 5.00'; }
                        }
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 5.0,
                        grid: { color: 'rgba(148, 163, 184, 0.15)' },
                        ticks: { stepSize: 1.0 }
                    },
                    x: {
                        grid: { display: false },
                        ticks: { font: { size: 12, weight: '600' } }
                    }
                }
            }
        });
    }

    // 2. F5 Smart Responder Algorithm Chart (Doughnut)
    const ctxAlgo = document.getElementById('f5AlgoChart');
    if (ctxAlgo) {
        new Chart(ctxAlgo, {
            type: 'doughnut',
            data: {
                labels: ['ความเชี่ยวชาญของแผนกตรงภัย (+3)', 'ภาระงานกู้ภัยที่ยังว่างอยู่ (+2)', 'ระยะห่าง GPS < 1km (+1)'],
                datasets: [{
                    data: [3, 2, 1],
                    backgroundColor: [
                        '#1e3a8a',  // Navy
                        '#10b981',  // Emerald
                        '#ea580c'   // Brand Orange
                    ],
                    borderColor: '#ffffff',
                    borderWidth: 2,
                    hoverOffset: 8
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                cutout: '70%',
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            font: { size: 11, weight: '500' },
                            padding: 15,
                            boxWidth: 12
                        }
                    }
                }
            }
        });
    }
}

/* ==========================================
   9. COPY SOURCE CODE BUTTONS
   ========================================== */
function initCopyCode() {
    const copyBtns = document.querySelectorAll('.code-copy-btn');
    copyBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            const codeWindow = btn.closest('.code-window');
            if (!codeWindow) return;

            const codeBody = codeWindow.querySelector('.code-body');
            if (!codeBody) return;

            // Get clean text inside code body (stripping any tags)
            const textToCopy = codeBody.textContent;

            navigator.clipboard.writeText(textToCopy).then(() => {
                const originalText = btn.textContent;
                btn.textContent = 'คัดลอกแล้ว! ✓';
                btn.style.borderColor = '#10b981';
                btn.style.color = '#10b981';

                setTimeout(() => {
                    btn.textContent = originalText;
                    btn.style.borderColor = '';
                    btn.style.color = '';
                }, 2000);
            }).catch(err => {
                console.error('Failed to copy text: ', err);
            });
        });
    });
}

/* ==========================================
   10. ANIMATED STATISTIC COUNTERS
   ========================================== */
function initAnimateCounters() {
    const statValues = document.querySelectorAll('.metric-value');

    const observerOptions = {
        root: null,
        rootMargin: '0px',
        threshold: 0.1
    };

    const countUpObserver = new IntersectionObserver((entries, observer) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const target = entry.target;
                const valueStr = target.textContent;
                
                // Extract floating numbers or percentages
                const numericMatch = valueStr.match(/[-+]?[0-9]*\.?[0-9]+/);
                if (numericMatch) {
                    const finalVal = parseFloat(numericMatch[0]);
                    const suffix = valueStr.replace(numericMatch[0], '');
                    const prefix = valueStr.substring(0, valueStr.indexOf(numericMatch[0]));

                    let currentVal = 0;
                    const duration = 1500; // ms
                    const steps = 60;
                    const increment = finalVal / steps;
                    const stepTime = duration / steps;
                    let step = 0;

                    const timer = setInterval(() => {
                        currentVal += increment;
                        step++;
                        
                        if (step >= steps) {
                            clearInterval(timer);
                            target.textContent = valueStr; // exact finish
                        } else {
                            // format output decimals if needed
                            const isFloat = finalVal % 1 !== 0;
                            const displayVal = isFloat ? currentVal.toFixed(2) : Math.round(currentVal);
                            target.textContent = prefix + displayVal + suffix;
                        }
                    }, stepTime);
                }
                observer.unobserve(target); // animate once
            }
        });
    }, observerOptions);

    statValues.forEach(val => {
        countUpObserver.observe(val);
    });
}
