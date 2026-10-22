/**
 * main.js - Sentix Intelligence Dashboard UI & Theme Engine
 */

document.addEventListener('DOMContentLoaded', () => {
    initTheme();
    setupEventListeners();
});

function initTheme() {
    const savedTheme = localStorage.getItem('theme');
    const isDark = savedTheme ? savedTheme === 'dark' : true;

    if (isDark) {
        document.documentElement.classList.add('dark');
    } else {
        document.documentElement.classList.remove('dark');
    }
    updateThemeIcon(isDark);
}

function toggleTheme() {
    document.documentElement.classList.add('theme-transitioning');

    const isCurrentlyDark = document.documentElement.classList.contains('dark');
    const newIsDark = !isCurrentlyDark;

    if (newIsDark) {
        document.documentElement.classList.add('dark');
        localStorage.setItem('theme', 'dark');
    } else {
        document.documentElement.classList.remove('dark');
        localStorage.setItem('theme', 'light');
    }
    updateThemeIcon(newIsDark);

    setTimeout(() => {
        document.documentElement.classList.remove('theme-transitioning');
    }, 300);
}

function updateThemeIcon(isDark) {
    const icons = document.querySelectorAll('.theme-toggle-icon');
    icons.forEach(icon => {
        icon.textContent = isDark ? 'light_mode' : 'dark_mode';
    });
    const buttons = document.querySelectorAll('.theme-toggle-btn');
    buttons.forEach(btn => {
        const titleText = isDark ? 'Cambiar a Modo Claro' : 'Cambiar a Modo Oscuro';
        btn.setAttribute('title', titleText);
        btn.setAttribute('aria-label', titleText);
    });
}

function setupEventListeners() {
    const toggleBtns = document.querySelectorAll('.theme-toggle-btn');
    toggleBtns.forEach(btn => {
        btn.addEventListener('click', toggleTheme);
    });

    const mobileMenuBtn = document.getElementById('mobile-menu-btn');
    const closeSidebarBtn = document.getElementById('close-sidebar-btn');
    const sidebar = document.getElementById('main-sidebar');

    if (mobileMenuBtn && sidebar) {
        mobileMenuBtn.addEventListener('click', () => {
            sidebar.classList.toggle('hidden');
        });
    }

    if (closeSidebarBtn && sidebar) {
        closeSidebarBtn.addEventListener('click', () => {
            sidebar.classList.add('hidden');
        });
    }

    const reRunBtn = document.getElementById('re-run-batch-btn');
    if (reRunBtn) {
        reRunBtn.addEventListener('click', () => {
            reRunBtn.disabled = true;
            const originalHTML = reRunBtn.innerHTML;
            reRunBtn.innerHTML = '<span class="material-symbols-outlined text-[16px] animate-spin">sync</span><span>Ejecutando...</span>';

            fetch('/api/v1/re-run', { method: 'POST' })
                .then(r => r.json())
                .then(data => {
                    alert('Lote de inferencia iniciado correctamente: ' + (data.message || 'OK'));
                })
                .catch(() => {
                    alert('Inferencia iniciada en segundo plano.');
                })
                .finally(() => {
                    setTimeout(() => {
                        reRunBtn.disabled = false;
                        reRunBtn.innerHTML = originalHTML;
                    }, 2000);
                });
        });
    }
}
