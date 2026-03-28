let selectedInstallType = null;
let selectedComponents = [];

// Sayfa yüklendiğinde sistem durumunu kontrol et
document.addEventListener('DOMContentLoaded', function() {
    checkStatus();
});

function addLog(message) {
    const logContainer = document.getElementById('logContainer');
    const timestamp = new Date().toLocaleTimeString();
    const logEntry = document.createElement('div');
    logEntry.innerHTML = `[${timestamp}] ${message}`;
    logContainer.appendChild(logEntry);
    logContainer.scrollTop = logContainer.scrollHeight;
}

async function checkStatus() {
    addLog('🔍 Sistem durumu kontrol ediliyor...');
    
    try {
        const response = await fetch('/api/status');
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const status = await response.json();
        console.log('API Response:', status); // Debug için
        
        // Response validation
        if (typeof status !== 'object' || status === null) {
            throw new Error('Geçersiz API yanıtı');
        }
        
        updateStatusCard(status);
        addLog('✅ Sistem durumu güncellendi');
    } catch (error) {
        console.error('Status check error:', error); // Debug için
        addLog('❌ Sistem durumu alınamadı: ' + error.message);
        
        // Fallback status for testing
        const fallbackStatus = {
            Connected: false,
            Schemas: [],
            StoredProcedureCounts: {},
            Timestamp: new Date().toISOString()
        };
        
        updateStatusCard(fallbackStatus);
    }
}

function updateStatusCard(status) {
    const statusCard = document.getElementById('statusCard');
    const statusContent = document.getElementById('statusContent');
    
    if (!status) {
        statusCard.className = 'card status-card error';
        statusContent.innerHTML = `
            <div class="alert alert-danger">
                <i class="fas fa-exclamation-triangle"></i>
                Sistem durumu alınamadı. Bağlantı problemi olabilir.
            </div>
        `;
        return;
    }
    
    // Güvenli erişim için default değerler
    const schemas = status.Schemas || [];
    const storedProcCounts = status.StoredProcedureCounts || {};
    const connected = status.Connected || false;
    
    const isHealthy = connected && schemas.length >= 4;
    statusCard.className = `card status-card ${isHealthy ? '' : 'warning'}`;
    
    const schemasHtml = ['src', 'ref', 'rpt', 'dof', 'ai', 'log', 'etl']
        .map(schema => {
            const exists = schemas.includes(schema);
            return `<span class="badge ${exists ? 'bg-success' : 'bg-secondary'} me-1">${schema}</span>`;
        }).join('');
    
    statusContent.innerHTML = `
        <div class="row">
            <div class="col-md-6">
                <h6><i class="fas fa-database"></i> Veritabanı Bağlantısı</h6>
                <span class="badge ${connected ? 'bg-success' : 'bg-danger'}">
                    ${connected ? 'Bağlı' : 'Bağlantı Yok'}
                </span>
                
                <h6 class="mt-3"><i class="fas fa-layer-group"></i> Şemalar</h6>
                <div>${schemasHtml}</div>
            </div>
            <div class="col-md-6">
                <h6><i class="fas fa-cog"></i> Stored Procedures</h6>
                <ul class="list-unstyled">
                    <li>🤖 AI: <span class="badge bg-info">${storedProcCounts.ai || 0}</span></li>
                    <li>📊 ETL: <span class="badge bg-info">${storedProcCounts.etl || 0}</span></li>
                    <li>📝 Log: <span class="badge bg-info">${storedProcCounts.log || 0}</span></li>
                    <li>📈 Report: <span class="badge bg-info">${storedProcCounts.rpt || 0}</span></li>
                </ul>
                
                <small class="text-muted">Son güncelleme: ${new Date(status.Timestamp).toLocaleString()}</small>
            </div>
        </div>
    `;
}

function selectInstallType(type) {
    selectedInstallType = type;
    
    // Tüm kartları temizle
    document.querySelectorAll('.component-card').forEach(card => {
        card.classList.remove('selected');
    });
    
    // Seçili kartı işaretle
    event.currentTarget.classList.add('selected');
    
    // Seçmeli kurulum için bileşen seçimini göster
    const componentSelection = document.getElementById('componentSelection');
    if (type === 'selective') {
        componentSelection.style.display = 'block';
    } else {
        componentSelection.style.display = 'none';
    }
    
    // Kurulum butonunu aktif et
    document.getElementById('installBtn').disabled = false;
    
    addLog(`📋 Kurulum tipi seçildi: ${type === 'full' ? 'Tam Kurulum' : 'Seçmeli Kurulum'}`);
}

async function startInstallation() {
    if (!selectedInstallType) {
        addLog('❌ Lütfen önce kurulum tipini seçin');
        return;
    }
    
    const installBtn = document.getElementById('installBtn');
    installBtn.disabled = true;
    installBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Kuruluyor...';
    
    addLog('🚀 Kurulum başlatılıyor...');
    
    try {
        let requestBody = {
            InstallationType: selectedInstallType
        };
        
        if (selectedInstallType === 'selective') {
            const checkboxes = document.querySelectorAll('#componentSelection input[type="checkbox"]:checked');
            selectedComponents = Array.from(checkboxes).map(cb => cb.value);
            
            if (selectedComponents.length === 0) {
                addLog('❌ Seçmeli kurulum için en az bir bileşen seçmelisiniz');
                installBtn.disabled = false;
                installBtn.innerHTML = '<i class="fas fa-play"></i> Kurulumu Başlat';
                return;
            }
            
            requestBody.Components = selectedComponents;
            addLog(`📦 Seçili bileşenler: ${selectedComponents.join(', ')}`);
        }
        
        const response = await fetch('/api/install', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(requestBody)
        });
        
        const result = await response.json();
        
        if (result.Success) {
            addLog('🎉 Kurulum başarıyla tamamlandı!');
            addLog('ℹ️  Sistem durumunu kontrol etmek için "Yenile" butonuna tıklayın');
            
            // Sistem durumunu otomatik güncelle
            setTimeout(checkStatus, 2000);
        } else {
            addLog('❌ Kurulum sırasında hata oluştu: ' + result.Message);
        }
        
    } catch (error) {
        addLog('❌ Kurulum hatası: ' + error.message);
    } finally {
        installBtn.disabled = false;
        installBtn.innerHTML = '<i class="fas fa-play"></i> Kurulumu Başlat';
    }
}

async function verifyInstallation() {
    addLog('🔍 Kurulum doğrulanıyor...');
    
    try {
        const response = await fetch('/api/verify', {
            method: 'POST'
        });
        
        const result = await response.json();
        
        if (result.Success) {
            addLog('✅ Kurulum doğrulaması başarılı');
        } else {
            addLog('❌ Kurulum doğrulaması başarısız: ' + result.Message);
        }
        
        // Sistem durumunu güncelle
        setTimeout(checkStatus, 1000);
        
    } catch (error) {
        addLog('❌ Doğrulama hatası: ' + error.message);
    }
}