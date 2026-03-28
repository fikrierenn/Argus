// Global variables
let currentSection = 'dashboard';
const apiBase = '/api/database';
const paginationState = {
    tables: { rows: [], page: 1, pageSize: 25 },
    views: { rows: [], page: 1, pageSize: 25 },
    procedures: { rows: [], page: 1, pageSize: 25 }
};

function getSectionState(section) {
    return paginationState[section];
}

function setRows(section, rows) {
    const state = getSectionState(section);
    if (!state) {
        return;
    }

    state.rows = Array.isArray(rows) ? rows : [];
    state.page = 1;
    renderSection(section);
}

function setPageSize(section, value) {
    const state = getSectionState(section);
    const size = Number.parseInt(value, 10);
    if (!state || !Number.isFinite(size) || size <= 0) {
        return;
    }

    state.pageSize = size;
    state.page = 1;
    renderSection(section);
}

function changePage(section, delta) {
    const state = getSectionState(section);
    if (!state) {
        return;
    }

    const totalPages = Math.max(1, Math.ceil(state.rows.length / state.pageSize));
    const nextPage = Math.min(totalPages, Math.max(1, state.page + delta));
    if (nextPage === state.page) {
        return;
    }

    state.page = nextPage;
    renderSection(section);
}

function paginate(section) {
    const state = getSectionState(section);
    if (!state) {
        return [];
    }

    const totalRows = state.rows.length;
    const totalPages = Math.max(1, Math.ceil(totalRows / state.pageSize));
    if (state.page > totalPages) {
        state.page = totalPages;
    }

    const start = (state.page - 1) * state.pageSize;
    const pageRows = state.rows.slice(start, start + state.pageSize);
    updatePager(section, state.page, totalPages, totalRows);
    return pageRows;
}

function updatePager(section, page, totalPages, totalRows) {
    const prevButton = document.getElementById(`${section}Prev`);
    const nextButton = document.getElementById(`${section}Next`);
    const info = document.getElementById(`${section}PageInfo`);

    if (prevButton) {
        prevButton.disabled = page <= 1;
    }
    if (nextButton) {
        nextButton.disabled = page >= totalPages;
    }
    if (info) {
        info.textContent = `Sayfa ${page} / ${totalPages} (${totalRows} kay\u0131t)`;
    }
}

function renderSection(section) {
    switch (section) {
        case 'tables':
            renderTables();
            break;
        case 'views':
            renderViews();
            break;
        case 'procedures':
            renderProcedures();
            break;
        default:
            break;
    }
}

function getValue(obj, ...keys) {
    if (!obj) {
        return undefined;
    }

    for (const key of keys) {
        if (Object.prototype.hasOwnProperty.call(obj, key)) {
            return obj[key];
        }
    }

    return undefined;
}

// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
    checkConnection();
    loadDashboard();
});

// Show/hide sections
function showSection(sectionName) {
    // Hide all sections
    document.querySelectorAll('.section').forEach(section => {
        section.style.display = 'none';
    });
    
    // Remove active class from all nav links
    document.querySelectorAll('.nav-link').forEach(link => {
        link.classList.remove('active');
    });
    
    // Show selected section
    document.getElementById(sectionName).style.display = 'block';
    
    // Add active class to clicked nav link
    document.querySelector(`[onclick="showSection('${sectionName}')"]`).classList.add('active');
    
    currentSection = sectionName;
    
    // Load section data
    switch(sectionName) {
        case 'tables':
            loadTables();
            break;
        case 'views':
            loadViews();
            break;
        case 'procedures':
            loadProcedures();
            break;
        case 'dashboard':
            loadDashboard();
            break;
    }
}

// Check database connection
async function checkConnection() {
    try {
        const response = await fetch(`${apiBase}/health`);
        const data = await response.json();
        
        const statusElement = document.getElementById('connectionStatus');
        const status = getValue(data, 'Status', 'status');
        if (status === 'Healthy') {
            statusElement.innerHTML = '<i class="fas fa-check-circle text-success me-1"></i>Ba\u011fl\u0131';
            showStatus('Veritaban\u0131 ba\u011flant\u0131s\u0131 ba\u015far\u0131l\u0131', 'success');
        } else {
            statusElement.innerHTML = '<i class="fas fa-times-circle text-danger me-1"></i>Ba\u011flant\u0131 Hatas\u0131';
            showStatus('Veritaban\u0131 ba\u011flant\u0131s\u0131 ba\u015far\u0131s\u0131z', 'danger');
        }
    } catch (error) {
        document.getElementById('connectionStatus').innerHTML = '<i class="fas fa-times-circle text-danger me-1"></i>Hata';
        showStatus('API ba\u011flant\u0131s\u0131 ba\u015far\u0131s\u0131z', 'danger');
    }
}

// Load dashboard data
async function loadDashboard() {
    try {
        // Load counts
        const [tablesRes, viewsRes, proceduresRes] = await Promise.all([
            fetch(`${apiBase}/tables`),
            fetch(`${apiBase}/views`),
            fetch(`${apiBase}/procedures`)
        ]);
        
        const tablesData = await tablesRes.json();
        const viewsData = await viewsRes.json();
        const proceduresData = await proceduresRes.json();
        
        const tablesList = getValue(tablesData, 'Data', 'data') || [];
        const viewsList = getValue(viewsData, 'Data', 'data') || [];
        const proceduresList = getValue(proceduresData, 'Data', 'data') || [];

        const tableCount = getValue(tablesData, 'Count', 'count') ?? tablesList.length;
        const viewCount = getValue(viewsData, 'Count', 'count') ?? viewsList.length;
        const procedureCount = getValue(proceduresData, 'Count', 'count') ?? proceduresList.length;

        document.getElementById('tableCount').textContent = tableCount || 0;
        document.getElementById('viewCount').textContent = viewCount || 0;
        document.getElementById('procedureCount').textContent = procedureCount || 0;
        
    } catch (error) {
        showStatus('Dashboard verileri y\u00fcklenirken hata', 'danger');
    }
}

// Load tables
async function loadTables() {
    try {
        const response = await fetch(`${apiBase}/tables`);
        const data = await response.json();

        const success = getValue(data, 'Success', 'success');
        const rows = getValue(data, 'Data', 'data');
        if (success && rows) {
            setRows('tables', rows);
        } else {
            setRows('tables', []);
        }
    } catch (error) {
        setRows('tables', []);
        showStatus('Tablolar y\u00fcklenirken hata', 'danger');
    }
}

function renderTables() {
    const tbody = document.querySelector('#tablesTable tbody');
    tbody.innerHTML = '';

    const rows = paginate('tables');
    rows.forEach(table => {
        const schemaName = getValue(table, 'SchemaName', 'schemaName') ?? '-';
        const objectName = getValue(table, 'ObjectName', 'objectName') ?? '-';
        const recordCount = getValue(table, 'RecordCount', 'recordCount');
        const createdDateRaw = getValue(table, 'CreatedDate', 'createdDate');
        const createdDate = createdDateRaw ? new Date(createdDateRaw) : null;
        const createdText = createdDate && !Number.isNaN(createdDate.getTime())
            ? createdDate.toLocaleDateString('tr-TR')
            : '-';
        const recordText = recordCount ?? '-';

        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${schemaName}</td>
            <td>${objectName}</td>
            <td>${recordText}</td>
            <td>${createdText}</td>
            <td>
                <button class="btn btn-sm btn-primary" onclick="viewTableData('${schemaName}', '${objectName}')">
                    <i class="fas fa-eye"></i> G\u00f6r\u00fcnt\u00fcle
                </button>
                <button class="btn btn-sm btn-info" onclick="viewTableColumns('${schemaName}', '${objectName}')">
                    <i class="fas fa-columns"></i> Kolonlar
                </button>
            </td>
        `;
        tbody.appendChild(row);
    });
}

// Load views
async function loadViews() {
    try {
        const response = await fetch(`${apiBase}/views`);
        const data = await response.json();

        const success = getValue(data, 'Success', 'success');
        const rows = getValue(data, 'Data', 'data');
        if (success && rows) {
            setRows('views', rows);
        } else {
            setRows('views', []);
        }
    } catch (error) {
        setRows('views', []);
        showStatus('View\'lar y\u00fcklenirken hata', 'danger');
    }
}

function renderViews() {
    const tbody = document.querySelector('#viewsTable tbody');
    tbody.innerHTML = '';

    const rows = paginate('views');
    rows.forEach(view => {
        const schemaName = getValue(view, 'SchemaName', 'schemaName') ?? '-';
        const objectName = getValue(view, 'ObjectName', 'objectName') ?? '-';
        const createdDateRaw = getValue(view, 'CreatedDate', 'createdDate');
        const createdDate = createdDateRaw ? new Date(createdDateRaw) : null;
        const createdText = createdDate && !Number.isNaN(createdDate.getTime())
            ? createdDate.toLocaleDateString('tr-TR')
            : '-';

        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${schemaName}</td>
            <td>${objectName}</td>
            <td>${createdText}</td>
            <td>
                <button class="btn btn-sm btn-primary" onclick="viewTableData('${schemaName}', '${objectName}')">
                    <i class="fas fa-eye"></i> G\u00f6r\u00fcnt\u00fcle
                </button>
            </td>
        `;
        tbody.appendChild(row);
    });
}

// Load procedures
async function loadProcedures() {
    try {
        const response = await fetch(`${apiBase}/procedures`);
        const data = await response.json();

        const success = getValue(data, 'Success', 'success');
        const rows = getValue(data, 'Data', 'data');
        if (success && rows) {
            setRows('procedures', rows);
        } else {
            setRows('procedures', []);
        }
    } catch (error) {
        setRows('procedures', []);
        showStatus('Stored procedure \u00e7al\u0131\u015ft\u0131r\u0131l\u0131rken hata', 'danger');
    }
}

function renderProcedures() {
    const tbody = document.querySelector('#proceduresTable tbody');
    tbody.innerHTML = '';

    const rows = paginate('procedures');
    rows.forEach(proc => {
        const schemaName = getValue(proc, 'SchemaName', 'schemaName') ?? '-';
        const objectName = getValue(proc, 'ObjectName', 'objectName') ?? '-';
        const createdDateRaw = getValue(proc, 'CreatedDate', 'createdDate');
        const createdDate = createdDateRaw ? new Date(createdDateRaw) : null;
        const createdText = createdDate && !Number.isNaN(createdDate.getTime())
            ? createdDate.toLocaleDateString('tr-TR')
            : '-';

        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${schemaName}</td>
            <td>${objectName}</td>
            <td>${createdText}</td>
            <td>
                <button class="btn btn-sm btn-success" onclick="executeProcedure('${schemaName}', '${objectName}')">
                    <i class="fas fa-play"></i> \u00c7al\u0131\u015ft\u0131r
                </button>
            </td>
        `;
        tbody.appendChild(row);
    });
}
// View table data
async function viewTableData(schema, table) {
    try {
        const response = await fetch(`${apiBase}/tables/${schema}/${table}/data?top=100`);
        const data = await response.json();
        
        const success = getValue(data, 'Success', 'success');
        if (success) {
            displayQueryResults(data, `${schema}.${table} - \u0130lk 100 Kay\u0131t`);
        } else {
            const message = getValue(data, 'Message', 'message') || 'Bilinmeyen hata';
            showStatus(`Tablo verisi al\u0131namad\u0131: ${message}`, 'danger');
        }
    } catch (error) {
        showStatus('Tablo verisi y\u00fcklenirken hata', 'danger');
    }
}

// View table columns
async function viewTableColumns(schema, table) {
    try {
        const response = await fetch(`${apiBase}/tables/${schema}/${table}/columns`);
        const data = await response.json();
        
        const success = getValue(data, 'Success', 'success');
        const rows = getValue(data, 'Data', 'data');
        if (success && rows) {
            const columns = rows.map(col => {
                const columnName = getValue(col, 'ColumnName', 'columnName') ?? '-';
                const dataType = getValue(col, 'DataType', 'dataType') ?? '-';
                const isNullable = getValue(col, 'IsNullable', 'isNullable');
                const maxLength = getValue(col, 'MaxLength', 'maxLength') ?? '-';
                const defaultValue = getValue(col, 'DefaultValue', 'defaultValue') ?? '-';
                const isPrimaryKey = getValue(col, 'IsPrimaryKey', 'isPrimaryKey');
                const nullableText = (isNullable === 'YES' || isNullable === true) ? 'Evet' : 'Hay\u0131r';
                const primaryKeyText = isPrimaryKey ? 'Evet' : 'Hay\u0131r';

                return {
                    'Kolon Ad\u0131': columnName,
                    'Veri Tipi': dataType,
                    'Null Olabilir': nullableText,
                    'Maksimum Uzunluk': maxLength,
                    'Varsay\u0131lan De\u011fer': defaultValue,
                    'Primary Key': primaryKeyText
                };
            });
            
            const result = {
                Success: true,
                Columns: Object.keys(columns[0]),
                Rows: columns,
                ExecutionTime: { TotalMilliseconds: 0 }
            };
            
            displayQueryResults(result, `${schema}.${table} - Kolon Bilgileri`);
        } else {
            const message = getValue(data, 'Message', 'message') || 'Bilinmeyen hata';
            showStatus(`Kolon bilgileri al\u0131namad\u0131: ${message}`, 'danger');
        }
    } catch (error) {
        showStatus('Kolon bilgileri y\u00fcklenirken hata', 'danger');
    }
}

// Execute stored procedure
async function executeProcedure(schema, procedure) {
    const params = prompt(`${schema}.${procedure} i\u00e7in parametreler (JSON format\u0131nda, \u00f6rn: {"param1": "value1"})`);
    
    try {
        let requestBody = {};
        if (params && params.trim()) {
            requestBody.Parameters = JSON.parse(params);
        }
        
        const response = await fetch(`${apiBase}/procedures/${schema}/${procedure}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(requestBody)
        });
        
        const data = await response.json();
        
        const success = getValue(data, 'Success', 'success');
        if (success) {
            displayQueryResults(data, `${schema}.${procedure} - Sonu\u00e7`);
        } else {
            const message = getValue(data, 'Message', 'message') || 'Bilinmeyen hata';
            showStatus(`Stored procedure \u00e7al\u0131\u015ft\u0131r\u0131lamad\u0131: ${message}`, 'danger');
        }
    } catch (error) {
        showStatus('Stored procedure \u00e7al\u0131\u015ft\u0131r\u0131l\u0131rken hata', 'danger');
    }
}

// Execute SQL query
async function executeQuery() {
    const sql = document.getElementById('sqlQuery').value.trim();
    
    if (!sql) {
        showStatus('L\u00fctfen bir SQL sorgusu girin', 'warning');
        return;
    }
    
    try {
        const response = await fetch(`${apiBase}/query`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ Sql: sql, MaxRows: 1000 })
        });
        
        const data = await response.json();
        
        const success = getValue(data, 'Success', 'success');
        if (success) {
            displayQueryResults(data, 'SQL Sorgu Sonucu');
        } else {
            const message = getValue(data, 'Message', 'message') || 'Bilinmeyen hata';
            showStatus(`Sorgu hatas\u0131: ${message}`, 'danger');
        }
    } catch (error) {
        showStatus('Sorgu \u00e7al\u0131\u015ft\u0131r\u0131l\u0131rken hata', 'danger');
    }
}

// Clear query
function clearQuery() {
    document.getElementById('sqlQuery').value = '';
    document.getElementById('queryResults').innerHTML = '';
}

// Display query results
function displayQueryResults(data, title) {
    const resultsDiv = document.getElementById('queryResults');
    const rows = getValue(data, 'Rows', 'rows') || [];
    const columns = getValue(data, 'Columns', 'columns') || [];
    const execTime = getValue(data, 'ExecutionTime', 'executionTime');
    const execMs = execTime?.TotalMilliseconds ?? execTime?.totalMilliseconds ?? 0;
    
    if (!rows || rows.length === 0) {
        resultsDiv.innerHTML = `
            <div class="alert alert-info">
                <h5>${title}</h5>
                <p>Sonu\u00e7 bulunamad\u0131.</p>
                <small>\u00c7al\u0131\u015fma s\u00fcresi: ${execMs}ms</small>
            </div>
        `;
        return;
    }
    
    let tableHtml = `
        <div class="mt-4">
            <h5>${title}</h5>
            <p class="text-muted">${rows.length} sat\u0131r - \u00c7al\u0131\u015fma s\u00fcresi: ${execMs}ms</p>
            <div class="table-responsive">
                <table class="table table-striped table-sm">
                    <thead class="table-dark">
                        <tr>
    `;
    
    // Headers
    columns.forEach(col => {
        tableHtml += `<th>${col}</th>`;
    });
    tableHtml += '</tr></thead><tbody>';
    
    // Rows
    rows.forEach(row => {
        tableHtml += '<tr>';
        columns.forEach(col => {
            let value = row[col];
            if (value === null || value === undefined) {
                value = '<span class="text-muted">NULL</span>';
            } else if (typeof value === 'string' && value.length > 100) {
                value = value.substring(0, 100) + '...';
            } else if (value instanceof Date) {
                value = value.toLocaleString('tr-TR');
            }
            tableHtml += `<td>${value}</td>`;
        });
        tableHtml += '</tr>';
    });
    
    tableHtml += '</tbody></table></div></div>';
    resultsDiv.innerHTML = tableHtml;
    
    // Switch to query section if not already there
    if (currentSection !== 'query') {
        showSection('query');
    }
}

// Show status message
function showStatus(message, type) {
    const badge = document.getElementById('statusBadge');
    badge.className = `status-badge alert alert-${type} alert-dismissible fade show`;
    badge.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    // Auto hide after 5 seconds
    setTimeout(() => {
        badge.innerHTML = '';
        badge.className = 'status-badge';
    }, 5000);
}
