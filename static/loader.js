// Legal footer injection for login page
(function() {
    function addLegalFooter() {
        // Check if footer already exists
        if (document.getElementById('legal-footer')) return;

        // Create footer element
        const footer = document.createElement('div');
        footer.id = 'legal-footer';
        footer.innerHTML = 'By using this service, you agree to our <a href="https://strali.solutions/impressum" target="_blank" style="color: #3b82f6; text-decoration: underline;">Imprint</a> and <a href="https://strali.solutions/datenschutz" target="_blank" style="color: #3b82f6; text-decoration: underline;">Privacy Policy</a>.';
        footer.style.cssText = 'position: fixed; bottom: 0; left: 0; right: 0; text-align: center; font-size: 12px; color: #888; padding: 15px; background: rgba(0,0,0,0.05); z-index: 9999;';

        document.body.appendChild(footer);
    }

    // Run when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', addLegalFooter);
    } else {
        addLegalFooter();
    }

    // Also run after a short delay to catch SPA navigation
    setTimeout(addLegalFooter, 1000);
    setTimeout(addLegalFooter, 3000);
})();
