// =============================================================================
// 1. NAVEGAÇÃO GERAL
//    Funções de navegação entre abas e controle visual da navbar superior.
// =============================================================================

// Navegando para uma aba da sidebar pelo seu data-value (chamada via R ou JS)
var openTab = function(tabName) {
  $('a', $('.sidebar')).each(function() {
    if (this.getAttribute('data-value') == tabName) {
      this.click();
    };
  });
};

// Exibindo ou ocultando o título da navbar conforme o scroll e o tamanho da tela.
// Em telas estreitas (≤ 1200px) o título fica sempre visível; em telas maiores,
// só aparece após rolar além do banner (#custom-banner).
function toggleNavbarTitle() {
  const banner = document.getElementById('custom-banner');
  const bannerHeight = banner ? banner.offsetHeight : 0;
  const screenWidth = window.innerWidth;

  if (screenWidth <= 1200) {
    // Forçando a exibição do título em telas pequenas
    document.body.classList.add('navbar-show-title');
  } else {
    // Exibindo ou ocultando conforme a posição do scroll em telas grandes
    if (window.scrollY > bannerHeight - 20) {
      document.body.classList.add('navbar-show-title');
    } else {
      document.body.classList.remove('navbar-show-title');
    }
  }
}

window.addEventListener('load', toggleNavbarTitle);
window.addEventListener('scroll', toggleNavbarTitle);
window.addEventListener('resize', toggleNavbarTitle);


// =============================================================================
// 2. NAVBAR — DROPDOWN E BOTÕES CIRCULARES
//    Controle de abertura/fechamento do menu suspenso multinível da navbar e
//    gerenciamento da classe de destaque (active-parent) nos itens de menu.
// =============================================================================

// Impedindo que o clique nos botões circulares (.circle-btn) cause o salto
// padrão de âncora (href="#")
$(document).on('click', '.circle-btn', function(e) {
  e.preventDefault();
});

// Inicializando a lógica do dropdown da navbar após o DOM estar pronto
$(function() {
  const navbarMenuSelector = '.navbar-nav.sidebar-menu';
  const navbarViewportPadding = 12;
  const navbarTooltipSpacing = 12;
  let navbarTooltipEl = null;
  let navbarTooltipTarget = null;
  let navbarRefreshFrame = null;

  // Removendo o comportamento padrão de clique do bootstrap nos toggles
  $('.navbar .dropdown-toggle').off('click');

  function getNavbarTooltipElement() {
    if (navbarTooltipEl) {
      return navbarTooltipEl;
    }

    navbarTooltipEl = document.createElement('div');
    navbarTooltipEl.className = 'tooltip-comp navbar-tooltip-popover position-right';
    navbarTooltipEl.style.display = 'none';
    navbarTooltipEl.innerHTML = '<div class="tooltip-comp-arrow"></div><div class="tooltip-comp-content"></div>';
    document.body.appendChild(navbarTooltipEl);

    return navbarTooltipEl;
  }

  function hideNavbarTooltip() {
    if (!navbarTooltipEl) {
      return;
    }

    navbarTooltipEl.style.opacity = '0';
    navbarTooltipEl.style.visibility = 'hidden';
    navbarTooltipEl.style.display = 'none';
    navbarTooltipEl.style.transform = 'translateX(4px)';
    navbarTooltipTarget = null;
  }

  function getNavbarTooltipText(link) {
    const label = link.querySelector('.navbar-dropdown-label');

    if (!label) {
      return '';
    }

    return label.textContent.replace(/\s+/g, ' ').trim();
  }

  function isNavbarLabelTruncated(link) {
    const label = link.querySelector('.navbar-dropdown-label');

    if (!label || !label.getClientRects().length) {
      return false;
    }

    // scrollWidth > clientWidth is unreliable when every ancestor has
    // overflow:hidden + max-width:100% (Chrome clamps scrollWidth to clientWidth).
    // Instead, find the first real text node and measure its Range rect, which
    // returns the full layout-box position regardless of overflow clipping.
    function findFirstTextNode(el) {
      for (var i = 0; i < el.childNodes.length; i++) {
        var child = el.childNodes[i];
        if (child.nodeType === Node.TEXT_NODE && child.textContent.trim()) {
          return child;
        }
        if (child.nodeType === Node.ELEMENT_NODE) {
          var found = findFirstTextNode(child);
          if (found) { return found; }
        }
      }
      return null;
    }

    var textNode = findFirstTextNode(label);
    if (!textNode) { return false; }

    var range = document.createRange();
    range.selectNode(textNode);
    var textRect = range.getBoundingClientRect();
    var labelRect = label.getBoundingClientRect();

    return Math.ceil(textRect.right) > Math.ceil(labelRect.right) + 1;
  }

  function positionNavbarTooltip(target) {
    const tooltip = getNavbarTooltipElement();
    const arrow = tooltip.querySelector('.tooltip-comp-arrow');
    const targetRect = target.getBoundingClientRect();

    if (!targetRect.width || !targetRect.height) {
      hideNavbarTooltip();
      return;
    }

    tooltip.style.display = 'block';
    tooltip.style.visibility = 'hidden';
    tooltip.style.opacity = '0';
    tooltip.style.transform = 'translateX(4px)';
    tooltip.classList.remove('position-top', 'position-bottom', 'position-left');
    tooltip.classList.add('position-right');

    const tooltipRect = tooltip.getBoundingClientRect();
    const left = targetRect.right + navbarTooltipSpacing;
    const maxTop = Math.max(navbarViewportPadding, window.innerHeight - navbarViewportPadding - tooltipRect.height);
    const preferredTop = targetRect.top + (targetRect.height / 2) - (tooltipRect.height / 2);
    const top = Math.min(Math.max(preferredTop, navbarViewportPadding), maxTop);
    const arrowTop = Math.min(
      Math.max((targetRect.top + (targetRect.height / 2)) - top, 16),
      Math.max(16, tooltipRect.height - 16)
    );

    tooltip.style.setProperty('left', `${left}px`, 'important');
    tooltip.style.setProperty('top', `${top}px`, 'important');
    arrow.style.setProperty('top', `${arrowTop}px`, 'important');
    arrow.style.setProperty('left', '-15px', 'important');
    arrow.style.setProperty('right', 'auto', 'important');
    arrow.style.setProperty('margin-top', '0', 'important');
  }

  function showNavbarTooltip(target) {
    const text = getNavbarTooltipText(target);

    if (!text || !isNavbarLabelTruncated(target)) {
      hideNavbarTooltip();
      return;
    }

    const tooltip = getNavbarTooltipElement();
    const content = tooltip.querySelector('.tooltip-comp-content');

    content.textContent = text;
    navbarTooltipTarget = target;
    positionNavbarTooltip(target);

    // Force a reflow so the browser commits the display:block/opacity:0 state
    // before the next frame — this ensures the CSS transition fires correctly.
    void tooltip.offsetHeight;

    requestAnimationFrame(function() {
      if (navbarTooltipTarget !== target) {
        return;
      }

      tooltip.style.visibility = 'visible';
      tooltip.style.opacity = '1';
      tooltip.style.transform = 'translateX(0)';
    });
  }

  function ensureNavbarDropdownLabels() {
    $(`${navbarMenuSelector} .dropdown-menu .nav-link`).each(function() {
      const link = this;
      const meaningfulNodes = Array.from(link.childNodes).filter(function(node) {
        return node.nodeType !== Node.TEXT_NODE || node.textContent.trim() !== '';
      });

      if (
        meaningfulNodes.length === 1 &&
        meaningfulNodes[0].nodeType === Node.ELEMENT_NODE &&
        meaningfulNodes[0].classList.contains('navbar-dropdown-label')
      ) {
        return;
      }

      const label = document.createElement('span');
      label.className = 'navbar-dropdown-label';

      while (link.firstChild) {
        label.appendChild(link.firstChild);
      }

      link.appendChild(label);
    });
  }

  function updateNavbarDropdownTooltips(scope) {
    const $scope = scope ? $(scope) : $(`${navbarMenuSelector} .dropdown-menu`);

    $scope.find('.dropdown-menu .nav-link, .nav-link').each(function() {
      const link = this;

      if (!link || !link.getClientRects().length) {
        return;
      }

      const fullText = getNavbarTooltipText(link);
      const isTruncated = isNavbarLabelTruncated(link);

      if (isTruncated && fullText) {
        link.setAttribute('data-navbar-tooltip', fullText);
      } else {
        link.removeAttribute('data-navbar-tooltip');
        if (navbarTooltipTarget === link) {
          hideNavbarTooltip();
        }
      }
    });
  }

  function resetNavbarMenuPosition($menu) {
    $menu.css({
      left: '',
      right: '',
      'max-width': ''
    });
    $menu.parent('.dropdown-submenu').removeClass('dropdown-open-left');
  }

  function positionNavbarMenu($menu) {
    if (!$menu.length || !$menu[0].getClientRects().length) {
      return;
    }

    resetNavbarMenuPosition($menu);
    $menu.css('max-width', `${window.innerWidth - (navbarViewportPadding * 2)}px`);

    const $parentItem = $menu.parent('.dropdown, .dropdown-submenu');

    if ($parentItem.hasClass('dropdown-submenu')) {
      const parentRect = $parentItem[0].getBoundingClientRect();
      let menuRect = $menu[0].getBoundingClientRect();
      const roomRight = window.innerWidth - parentRect.right - navbarViewportPadding;
      const roomLeft = parentRect.left - navbarViewportPadding;

      if (menuRect.right > window.innerWidth - navbarViewportPadding && roomLeft > roomRight) {
        $parentItem.addClass('dropdown-open-left');
        menuRect = $menu[0].getBoundingClientRect();
      }

      if (menuRect.right > window.innerWidth - navbarViewportPadding || menuRect.left < navbarViewportPadding) {
        const availableWidth = Math.max(180, Math.min(window.innerWidth - (navbarViewportPadding * 2), Math.max(roomLeft, roomRight)));
        $menu.css('max-width', `${availableWidth}px`);

        if (roomLeft >= roomRight) {
          $parentItem.addClass('dropdown-open-left');
        }
      }
    } else {
      let menuRect = $menu[0].getBoundingClientRect();

      if (menuRect.right > window.innerWidth - navbarViewportPadding) {
        $menu.css({ left: 'auto', right: '0' });
        menuRect = $menu[0].getBoundingClientRect();
      }

      if (menuRect.left < navbarViewportPadding) {
        $menu.css({ left: '0', right: 'auto' });
      }
    }

    updateNavbarDropdownTooltips($menu);
  }

  function refreshOpenNavbarMenus() {
    $(`${navbarMenuSelector} .dropdown-menu.show`).each(function() {
      positionNavbarMenu($(this));
    });

    if (navbarTooltipTarget) {
      positionNavbarTooltip(navbarTooltipTarget);
      navbarTooltipEl.style.visibility = 'visible';
      navbarTooltipEl.style.opacity = '1';
      navbarTooltipEl.style.display = 'block';
      navbarTooltipEl.style.transform = 'translateX(0)';
    }
  }

  function scheduleNavbarRefresh() {
    if (navbarRefreshFrame !== null) {
      cancelAnimationFrame(navbarRefreshFrame);
    }

    navbarRefreshFrame = requestAnimationFrame(function() {
      navbarRefreshFrame = null;
      refreshOpenNavbarMenus();
    });
  }

  // Limpando os timers de fechamento de todos os ancestrais de um elemento
  function clearParentTimers($el) {
    $el.parents('.dropdown, .dropdown-submenu').each(function() {
      clearTimeout($(this).data('hideTimer'));
    });
  }

  // Abrindo o submenu ao passar o mouse (nível 1 e subníveis)
  $('.navbar').on('mouseenter', '.dropdown, .dropdown-submenu', function(e) {
    const $this = $(this);

    // Cancelando qualquer timer de fechamento pendente no elemento e em seus pais
    clearTimeout($this.data('hideTimer'));
    clearParentTimers($this);

    // Exibindo o menu atual
    $this.addClass('show').children('.dropdown-menu').addClass('show');
    scheduleNavbarRefresh();

    // Fechando submenus irmãos que possam ter ficado abertos
    $this.siblings().removeClass('show').find('.show').removeClass('show');

    e.stopPropagation();
  }).on('mouseleave', '.dropdown, .dropdown-submenu', function(e) {
    const $this = $(this);
    const related = e.relatedTarget;

    // Não iniciando o timer se o mouse foi para um descendente direto do elemento
    if (related && $this[0].contains(related)) {
      return;
    }

    // Agendando o fechamento do menu com pequeno atraso para evitar piscar
    const timer = setTimeout(function() {
      $this.removeClass('show').children('.dropdown-menu').removeClass('show');
      // Garantindo que todos os submenus filhos também sejam fechados
      $this.find('.show').removeClass('show');

      if (navbarTooltipTarget && $this[0].contains(navbarTooltipTarget)) {
        hideNavbarTooltip();
      }
    }, 200);

    $this.data('hideTimer', timer);
  });

  $('.navbar').on('mouseenter focusin', '.dropdown-menu .nav-link', function() {
    showNavbarTooltip(this);
  });

  $('.navbar').on('mouseleave focusout', '.dropdown-menu .nav-link', function(e) {
    const related = e.relatedTarget;

    if (related && this.contains(related)) {
      return;
    }

    hideNavbarTooltip();
  });

  // Sincronizando a seleção do item de menu com o Shiny (input$navmenu) e
  // clicando na aba correspondente da sidebar ao mesmo tempo
  $('.navbar').on('mousedown', '.dropdown-menu a[data-value]', function(e) {
    e.stopPropagation();
    const $mainParent = $(this).closest('.nav-item.dropdown');
    const val = $(this).attr('data-value');
    // Extraindo o prefixo para encontrar a aba pai na sidebar (ex: "indicadores-xyz" → "indicadores")
    const parent = val.includes('-') ? val.substring(0, val.lastIndexOf('-')) : val;

      if (parent && parent !== 'home') {
        iniciarBotaoAtualizar();
      }

    if (typeof Shiny !== 'undefined') {
      Shiny.setInputValue('navmenu', val, { priority: 'event' });
    }

    // Ativando a aba correspondente na sidebar lateral
    const $side = $('.sidebar a[data-value="' + parent + '"]');
    if ($side.length) { $side[0].click(); }

    // Marcando o menu pai como ativo e fechando todos os dropdowns abertos
    $('.navbar .nav-item.dropdown').removeClass('active-parent');
    $mainParent.addClass('active-parent');
    $('.navbar .show').removeClass('show');
    hideNavbarTooltip();
  });

  // Removendo o destaque de dropdown ao clicar em abas simples (sem submenu)
  $('.navbar').on('click', '.nav-item:not(.dropdown) > .nav-link', function() {
    $('.navbar .nav-item.dropdown').removeClass('active-parent');

    var href = String($(this).attr('href') || '');
    var dataValue = String($(this).attr('data-value') || '');
    var isVisaoGeral = href.indexOf('#shiny-tab-visao_geral') !== -1 || dataValue === 'visao_geral';

    if (isVisaoGeral) {
      iniciarBotaoAtualizar();
    }
  });

  // Marcando o dropdown "Indicadores" como ativo ao clicar nos botões circulares
  // (que redirecionam para indicadores individuais a partir de outras abas)
  $(document).on('click', '.circle-btn', function() {
    $('.navbar .nav-item.dropdown').removeClass('active-parent');
    $('.navbar .nav-item.dropdown').filter(function() {
      return $(this).text().trim().includes("Indicadores");
    }).addClass('active-parent');
  });

  $(window).on('resize', function() {
    scheduleNavbarRefresh();
    hideNavbarTooltip();
  });

  window.addEventListener('scroll', hideNavbarTooltip, true);

  ensureNavbarDropdownLabels();
  scheduleNavbarRefresh();
});


// =============================================================================
// 3. LAYOUT: POSICIONAMENTO DE CARDS FIXOS (STICKY)
//    Calcula e aplica o deslocamento vertical correto nos cabeçalhos fixos dos
//    cards de filtros e visualizações, levando em conta a altura da navbar fixa
//    e do .div-infos-principais (barra de título + chips abaixo da navbar).
// =============================================================================

// // Gerenciamento completo de posicionamento e altura do painel de filtros.
// Utiliza posicionamento fixo sincronizado no desktop para que o navegador
// NUNCA empurre o cabeçalho para cima durante a rolagem (eliminando 100% o jitter),
// enquanto encolhe suavemente o card-body para acompanhar a base das visualizações.
// Guarda do último estado aplicado ao painel fixo: o reflow forçado só faz
// sentido quando este estado mudou (ver forcarReflowCardFiltros).
var _phUltimoEstadoSticky = null;
var _phStickyMudou = true;

function assinaturaEstadoSticky() {
  var stickyPanel = document.querySelector('.conditional-sticky');
  var cardBody = document.querySelector('#card-filters .card-body');
  var partes = [];
  if (stickyPanel) {
    partes.push(stickyPanel.style.position, stickyPanel.style.top,
      stickyPanel.style.left, stickyPanel.style.width, stickyPanel.style.transform);
  }
  if (cardBody) {
    partes.push(cardBody.style.maxHeight);
  }
  return partes.join('|');
}

function atualizarPosicionamentoCardFiltros() {
  const col = document.querySelector('.col-filtros-global');
  const stickyPanel = document.querySelector('.conditional-sticky');
  const cardBody = document.querySelector('#card-filters .card-body');
  const divInfosPrincipais = document.querySelector('.div-infos-principais');
  if (!col || !stickyPanel || !cardBody) return;

  // Em telas mobile (<= 1199px), o painel é um drawer e usa estilos mobile
  if (window.innerWidth <= 1199) {
    stickyPanel.style.position = '';
    stickyPanel.style.top = '';
    stickyPanel.style.left = '';
    stickyPanel.style.width = '';
    stickyPanel.style.transform = '';
    cardBody.style.maxHeight = '';
    var assinaturaMobile = assinaturaEstadoSticky();
    _phStickyMudou = (assinaturaMobile !== _phUltimoEstadoSticky);
    _phUltimoEstadoSticky = assinaturaMobile;
    return;
  }

  // offsetHeight (não clientHeight, que exclui a borda inferior de 1px da
  // barra): sem esse 1px o topo fixo ficava 1px acima do card da direita.
  const baseAltura = divInfosPrincipais ? divInfosPrincipais.offsetHeight : 0;
  // Folga = margin-bottom real da barra (.div-infos-principais, 16px): o respiro
  // entre a barra e os cards saiu da .row-visualizations (padding-top removido)
  // para a margem da própria barra — lida do estilo computado para o topo do
  // card acompanhar qualquer ajuste futuro sem hardcode. Soma-se a altura REAL
  // da navbar fixa (o AdminLTE presume 57px, mas a navbar customizada é mais
  // alta — ver atualizarAlturaNavbar).
  const margemInfos = divInfosPrincipais
    ? (parseFloat(window.getComputedStyle(divInfosPrincipais).marginBottom) || 0)
    : 0;
  const stickyTop = baseAltura + alturaNavbarFixa() + margemInfos;

  // Alinha horizontalmente com o espaço interno da coluna de filtros do grid (descontando o gutter/padding)
  const colRect = col.getBoundingClientRect();
  const colComputed = window.getComputedStyle(col);
  const padLeft = parseFloat(colComputed.paddingLeft) || 0;
  const padRight = parseFloat(colComputed.paddingRight) || 0;

  stickyPanel.style.position = 'fixed';
  stickyPanel.style.top = `${stickyTop}px`;
  stickyPanel.style.left = `${colRect.left + padLeft}px`;
  stickyPanel.style.width = `${colRect.width - padLeft - padRight}px`;

  // Overhead não-scrollável do card: header + footer + margens
  const header = document.querySelector('#card-filters .card-header');
  const footer = document.querySelector('#card-filters .card-footer');
  const headerHeight = header ? header.offsetHeight : 48;
  const footerHeight = footer ? footer.offsetHeight : 58;
  const overheadCard = headerHeight + footerHeight + 16;

  // Altura padrão do card-body definida pelo CSS com base na viewport
  const isNavbarTitle = document.body.classList.contains('navbar-show-title');
  const offsetVh = isNavbarTitle ? 363 : 330;
  const viewportMaxHeight = Math.max(100, window.innerHeight - offsetVh);

  // Espaço disponível entre o topo fixo e a borda inferior da área de visualizações
  const espacoDisponivel = colRect.bottom - stickyTop;
  const minCardHeight = overheadCard + 40;

  // Captura a proporção de rolagem relativa antes do ajuste de altura para preservar a ancoragem
  const prevMaxScroll = cardBody.scrollHeight - cardBody.clientHeight;
  const scrollRatio = prevMaxScroll > 0 ? (cardBody.scrollTop / prevMaxScroll) : 0;

  if (espacoDisponivel >= (viewportMaxHeight + overheadCard)) {
    // Espaço abundante: card tem altura máxima normal e fica em translateY(0)
    stickyPanel.style.transform = '';
    cardBody.style.maxHeight = '';
  } else if (espacoDisponivel >= minCardHeight) {
    // Faixa de encolhimento: o topo continua fixo no stickyTop e o body encolhe
    stickyPanel.style.transform = '';
    const bodyMaxHeight = Math.max(40, Math.floor(espacoDisponivel - overheadCard));
    cardBody.style.maxHeight = `${bodyMaxHeight}px`;
  } else {
    // O usuário rolou além das visualizações: o card sobe suavemente com a página
    cardBody.style.maxHeight = '40px';
    const shiftUp = espacoDisponivel - minCardHeight;
    stickyPanel.style.transform = `translateY(${shiftUp}px)`;
  }

  // Preserva a ancoragem de rolagem relativa (mantém quem estava no fundo exatamente no fundo)
  if (scrollRatio > 0) {
    const newMaxScroll = cardBody.scrollHeight - cardBody.clientHeight;
    if (newMaxScroll > 0) {
      cardBody.scrollTop = Math.round(scrollRatio * newMaxScroll);
    }
  }

  var assinaturaNova = assinaturaEstadoSticky();
  _phStickyMudou = (assinaturaNova !== _phUltimoEstadoSticky);
  _phUltimoEstadoSticky = assinaturaNova;
}

// Agendamento das atualizações de layout: no máximo 1 execução por quadro.
// Durante a cascata de filtros o Shiny dispara dezenas de `inputchanged` em
// sequência; sem este agendamento cada um deles forçava leituras de layout +
// reflow completos, prendendo a thread principal e deixando o card pesado.
var _phLayoutAgendado = false;
var _phLayoutForcar = false;

function cardFiltrosDispensavel() {
  // Na aba home o card de filtros fica oculto: não há posição a calcular.
  // Ao sair da home, a troca da aba dispara `inputchanged` com forçar=true.
  return document.body.classList.contains('home-ativa');
}

function agendarAtualizacaoLayout(forcar) {
  if (forcar) _phLayoutForcar = true;
  if (_phLayoutAgendado || document.hidden) return;
  _phLayoutAgendado = true;
  var rodar = function() {
    _phLayoutAgendado = false;
    if (document.hidden) {
      _phLayoutForcar = false;
      return;
    }
    var forcarAgora = _phLayoutForcar;
    _phLayoutForcar = false;
    if (cardFiltrosDispensavel() && !forcarAgora) {
      // Card oculto e sem troca de aba: só mantém o spacer em dia.
      atualizarAlturaSpacer();
      return;
    }
    atualizarTudo();
  };
  if (typeof window.requestAnimationFrame === 'function') {
    window.requestAnimationFrame(rodar);
  } else {
    setTimeout(rodar, 0);
  }
}

// Posicionamento durante a rolagem: agendado por quadro e pulado com o card
// oculto (ex.: aba home), pois não há nada visível a reposicionar.
var _phScrollAgendado = false;
function agendarPosicionamentoScroll() {
  if (_phScrollAgendado || document.hidden) return;
  if (cardFiltrosDispensavel()) return;
  _phScrollAgendado = true;
  var rodar = function() {
    _phScrollAgendado = false;
    if (document.hidden || cardFiltrosDispensavel()) return;
    atualizarPosicionamentoCardFiltros();
  };
  if (typeof window.requestAnimationFrame === 'function') {
    window.requestAnimationFrame(rodar);
  } else {
    setTimeout(rodar, 0);
  }
}

// Acionando todas as atualizações de layout de uma só vez
function atualizarTudo() {
  atualizarAlturaNavbar();
  atualizarPosicionamentoCardFiltros();
  atualizarAlturaSpacer();
  forcarReflowCardFiltros();
}

// Forçando reflow síncrono no .card-body do card de filtros. Útil após
// mudanças de estado sticky (ex: entrada/saída do limite da coluna
// .conditional-sticky), onde o browser pode manter um cache de composição
// desatualizado, fazendo o conteúdo aparecer cortado mesmo com scrollTop = 0.
// Roda SOMENTE quando o posicionamento mudou de fato (sinal
// _phStickyMudou): nas demais vezes seria um reflow forçado sem efeito.
function forcarReflowCardFiltros() {
  if (!_phStickyMudou) return;
  var cardBody = document.querySelector('#card-filters .card-body');
  if (cardBody) {
    // Leitura de offsetHeight força reflow do layout box.
    void cardBody.offsetHeight;
  }
  var card = document.getElementById('card-filters');
  if (card) {
    void card.offsetHeight;
  }
  var sticky = document.querySelector('.conditional-sticky');
  if (sticky) {
    void sticky.offsetHeight;
  }
}

$(document).on("shiny:inputchanged", function(event) {
  // A troca de aba (abas) sempre roda completo: a classe home-ativa pode ainda
  // estar desatualizada neste ponto, e o custo de 1 execução é irrelevante.
  agendarAtualizacaoLayout(event && event.name === 'abas');
});
window.addEventListener("load", function() { agendarAtualizacaoLayout(true); });
window.addEventListener("resize", function() { agendarAtualizacaoLayout(true); });
window.addEventListener("scroll", agendarPosicionamentoScroll, { passive: true });
// Eventos chegados com a guia oculta foram pulados: ao voltar, reagenda.
document.addEventListener("visibilitychange", function() {
  if (!document.hidden) agendarAtualizacaoLayout(true);
});


// =============================================================================
// 4. VALUEBOXES — AJUSTE AUTOMÁTICO DE FONTE
//    Reduz dinamicamente o tamanho da fonte nos elementos de texto das
//    ValueBoxes para que o conteúdo sempre caiba sem transbordar o contêiner,
//    independente do tamanho do texto ou da resolução da tela.
// =============================================================================

// Ajustando a fonte dos elementos .fonte-nome-hospital para caberem na largura
// disponível do contêiner pai (lógica simples por largura)
function ajustaFonteNomeHospital() {
  var elements = document.querySelectorAll('.fonte-nome-hospital');
  elements.forEach(function(el) {
    var parentWidth = el.parentElement.clientWidth;
    // Elemento em aba inativa: dimensões retornam 0, ignorar para não corromper o estado
    if (parentWidth === 0) return;
    el.style.opacity = '0';
    el.style.setProperty('font-size', '45px');
    while (
      (el.scrollWidth > parentWidth || el.scrollHeight > el.clientHeight) &&
      parseInt(window.getComputedStyle(el).fontSize) > 12
    ) {
      var currentSize = parseInt(window.getComputedStyle(el).fontSize);
      el.style.setProperty('font-size', (currentSize - 1) + 'px', 'important');
    }
    // Revela o elemento somente após o ajuste final da fonte
    el.style.opacity = '1';
  });
}

$(document).on("shiny:inputchanged", ajustaFonteNomeHospital);
window.addEventListener('load', ajustaFonteNomeHospital);
window.addEventListener('resize', ajustaFonteNomeHospital);

function ajustarIdentificacaoHospital() {
  var rootStyles = window.getComputedStyle(document.documentElement);
  var rootFontSize = parseFloat(rootStyles.fontSize) || 16;

  function cssLengthToPx(value, fallback) {
    var normalizedValue = (value || '').toString().trim();

    if (!normalizedValue) {
      return fallback;
    }

    if (normalizedValue.endsWith('rem')) {
      return parseFloat(normalizedValue) * rootFontSize;
    }

    if (normalizedValue.endsWith('px')) {
      return parseFloat(normalizedValue);
    }

    return parseFloat(normalizedValue) || fallback;
  }

  var maxSize = cssLengthToPx(rootStyles.getPropertyValue('--fonte-titulos-size'), 28);
  var minSize = cssLengthToPx(rootStyles.getPropertyValue('--fonte-muito-grande-size'), 16);
  var isMobile = window.matchMedia('(max-width: 767.98px)').matches;
  var elements = document.querySelectorAll('.texto-auto-ajustavel-identificacao-hospital, .texto-auto-ajustavel-nowrap');

  elements.forEach(function(el) {
    var parentWidth = el.parentElement ? el.parentElement.clientWidth : 0;
    if (parentWidth === 0) return;

    el.style.opacity = '0';
    el.style.removeProperty('font-size');

    if (isMobile) {
      el.style.opacity = '1';
      return;
    }

    el.style.setProperty('font-size', maxSize + 'px', 'important');

    while (
      el.scrollWidth > parentWidth &&
      parseFloat(window.getComputedStyle(el).fontSize) > minSize
    ) {
      var currentSize = parseFloat(window.getComputedStyle(el).fontSize);
      el.style.setProperty('font-size', (currentSize - 1) + 'px', 'important');
    }

    el.style.opacity = '1';
  });
}

// Encolhendo o texto dos elementos .texto-auto-ajustavel nas ValueBoxes genéricas.
// Mede o espaço disponível descontando título, botão e paddings, depois reduz
// a fonte iterativamente até o texto caber na altura calculada.
function aplicarAutoShrink() {
  $('.texto-auto-ajustavel').each(function() {
    let el = $(this)[0];
    let smallBox = $(this).closest('.small-box')[0];
    // Elemento em aba inativa: dimensões retornam 0, ignorar para não corromper o estado
    if (!smallBox || smallBox.offsetWidth === 0) return;
    el.style.opacity = '0';
    let title = $(this).siblings('.value-title')[0];

    // Escondendo o texto temporariamente para medir o contêiner sem interferência
    let originalDisplay = el.style.display;
    el.style.display = 'none';

    // Medindo a altura total da caixa e descontando os paddings internos
    let boxHeight = smallBox.clientHeight;
    let boxStyle = window.getComputedStyle(smallBox);
    let paddingTotal = (parseFloat(boxStyle.paddingTop) || 0) + (parseFloat(boxStyle.paddingBottom) || 0);

    let inner = smallBox.querySelector('.inner');
    if (inner) {
      let innerStyle = window.getComputedStyle(inner);
      paddingTotal += (parseFloat(innerStyle.paddingTop) || 0) + (parseFloat(innerStyle.paddingBottom) || 0);
    }
    let boxInnerHeight = boxHeight - paddingTotal;

    // Medindo a altura ocupada pelo título acima do texto
    let titleStyle = window.getComputedStyle(title);
    let titleHeight = title.offsetHeight + (parseFloat(titleStyle.marginTop) || 0) + (parseFloat(titleStyle.marginBottom) || 0);

    // Medindo a altura do botão (se existir) para descontar do espaço disponível
    let btnWrapper = smallBox.querySelector('.wrapper-botao-valuebox');
    let spaceToDiscount = 0;

    if (btnWrapper) {
      let btnStyle = window.getComputedStyle(btnWrapper);
      spaceToDiscount = btnWrapper.offsetHeight + (parseFloat(btnStyle.marginTop) || 0) + 20;
    } else {
      // Usando respiro padrão quando não há botão
      spaceToDiscount = 42;
    }

    // Calculando a altura efetivamente disponível para o texto
    let availableHeight = boxInnerHeight - titleHeight - spaceToDiscount;

    // Restaurando a exibição do texto e aplicando a altura máxima calculada
    el.style.display = originalDisplay === 'none' ? '' : originalDisplay;
    el.style.removeProperty('font-size');

    availableHeight = availableHeight > 0 ? availableHeight : 20;
    el.style.setProperty('max-height', availableHeight + 'px', 'important');

    // Reduzindo a fonte iterativamente até o texto caber na altura disponível
    let currentSize = parseFloat(window.getComputedStyle(el).fontSize);
    let minSize = 11;

    while (el.scrollHeight > el.clientHeight && currentSize > minSize) {
      currentSize -= 0.5;
      el.style.setProperty('font-size', currentSize + 'px', 'important');
    }
    // Revela o elemento somente após o ajuste final da fonte
    el.style.opacity = '1';
  });
}

// Encolhendo o texto do nome do hospital (.texto-auto-ajustavel-hospital).
// Segue a mesma lógica de aplicarAutoShrink, mas descontando o texto de
// localidade abaixo em vez de um título acima (a caixa é centralizada pelo CSS).
function aplicarAutoShrinkHospital() {
  $('.texto-auto-ajustavel-hospital').each(function() {
    let el = $(this)[0];
    let smallBox = $(this).closest('.small-box')[0];
    // Elemento em aba inativa: dimensões retornam 0, ignorar para não corromper o estado
    if (!smallBox || smallBox.offsetWidth === 0) return;
    el.style.opacity = '0';
    let localText = $(this).siblings('.local-texto-hospital')[0];

    // Escondendo temporariamente para medir o contêiner sem interferência
    let originalDisplay = el.style.display;
    el.style.display = 'none';

    // Medindo a altura total da caixa e descontando os paddings internos
    let boxHeight = smallBox.clientHeight;
    let boxStyle = window.getComputedStyle(smallBox);
    let paddingTotal = (parseFloat(boxStyle.paddingTop) || 0) + (parseFloat(boxStyle.paddingBottom) || 0);

    let inner = smallBox.querySelector('.inner');
    if (inner) {
      let innerStyle = window.getComputedStyle(inner);
      paddingTotal += (parseFloat(innerStyle.paddingTop) || 0) + (parseFloat(innerStyle.paddingBottom) || 0);
    }
    let boxInnerHeight = boxHeight - paddingTotal;

    // Medindo a altura do texto de localidade abaixo do nome do hospital
    let localHeight = 0;
    if (localText) {
      let localStyle = window.getComputedStyle(localText);
      localHeight = localText.offsetHeight + (parseFloat(localStyle.marginTop) || 0) + (parseFloat(localStyle.marginBottom) || 0);
    }

    // Calculando a altura disponível (sem descontar título, pois a caixa é centralizada)
    let availableHeight = boxInnerHeight - localHeight - 20;

    // Restaurando a exibição e aplicando a altura máxima calculada
    el.style.display = originalDisplay === 'none' ? '' : originalDisplay;
    el.style.removeProperty('font-size');

    availableHeight = availableHeight > 0 ? availableHeight : 20;
    el.style.setProperty('max-height', availableHeight + 'px', 'important');

    // Reduzindo a fonte de 1 em 1px (mais rápido, pois começa em ~50px)
    let currentSize = parseFloat(window.getComputedStyle(el).fontSize);
    let minSize = 14;

    while (el.scrollHeight > el.clientHeight && currentSize > minSize) {
      currentSize -= 1;
      el.style.setProperty('font-size', currentSize + 'px', 'important');
    }
    // Revela o elemento somente após o ajuste final da fonte
    el.style.opacity = '1';
  });
}

// Disparando ambas as funções de auto-encolhimento nos momentos relevantes.
// Executa imediatamente para evitar um frame inicial com fonte grande e
// repete no próximo frame para consolidar medidas após reflow/repaint.
let autoShrinkFrameId = null;

function executarAutoShrinkValueBoxes() {
  aplicarAutoShrink();
  aplicarAutoShrinkHospital();
  ajustarIdentificacaoHospital();
}

function agendarAutoShrinkValueBoxes() {
  executarAutoShrinkValueBoxes();

  if (autoShrinkFrameId !== null) {
    cancelAnimationFrame(autoShrinkFrameId);
  }

  autoShrinkFrameId = requestAnimationFrame(function() {
    autoShrinkFrameId = null;
    executarAutoShrinkValueBoxes();
  });
}

$(document).ready(function() {
  agendarAutoShrinkValueBoxes();
});

$(document).on('shiny:value', function() {
  agendarAutoShrinkValueBoxes();
});

$(document).on('shiny:visualchange', function(event) {
  if (event && event.visible) {
    agendarAutoShrinkValueBoxes();
  }
});

$(window).on('resize', function() {
  agendarAutoShrinkValueBoxes();
});

if (window.visualViewport) {
  window.visualViewport.addEventListener('resize', agendarAutoShrinkValueBoxes);
}


// =============================================================================
// 5. ACCORDIONS (SEÇÕES DOBRÁVEIS DO PAINEL DE FILTROS)
//    Recebe mensagens do servidor R para abrir ou fechar seções accordion
//    customizadas (componente accordionSection de funcoes_globais.R) e
//    sincroniza o estado de volta para o Shiny via setInputValue.
// =============================================================================

// Antes de enviar o botão da Home ao servidor, garante que o hospital
// selecionado no DOM seja sincronizado no input auxiliar _userclick. Isso
// evita que o primeiro clique use o hospital padrão em vez do escolhido.
$(document).on("mousedown", "button[id$='-btn_ir_visao_geral']", function() {
  if (typeof Shiny === "undefined") return;

  var $scope = $(this).closest(".home-filter-card");
  var $select = $scope.find("select[id$='-home_input_hospital']");

  if (!$select.length) {
    $select = $("select[id$='-home_input_hospital']").first();
  }

  if (!$select.length) return;

  var value = $select.val();
  if (Array.isArray(value)) {
    value = value[0];
  }

  if (value !== undefined && value !== null && value !== "") {
    Shiny.setInputValue($select.attr("id") + "_userclick", value, { priority: "event" });
  }
});

// Dispara o botão global de atualizar quando o módulo Home pede a navegação
// para a Visão Geral. O envio usa um pequeno delay para garantir que os
// inputs da sidebar já tenham sido atualizados antes do trigger.
Shiny.addCustomMessageHandler("home-trigger-atualizar", function(message) {
  const delay = Number(message && message.delay ? message.delay : 0);

  setTimeout(function() {
    iniciarBotaoAtualizar();
    Shiny.setInputValue('btn_atualizar', 'home_btn_click', { priority: 'event' });
  }, delay);
});

// Abrindo ou fechando uma seção accordion por mensagem enviada do servidor R
Shiny.addCustomMessageHandler("accordion-set", function(message) {
  const id = message.id;
  const state = message.state; // "open" ou "closed"

  const container = document.getElementById(id + "-header-container");
  const icon = document.getElementById(id + "-icon");
  const body = document.getElementById(id + "-body");

  if (!container || !icon || !body) return;

  const isClosed = container.classList.contains("closed");

  if (state === "closed" && !isClosed) {
    container.classList.add("closed");
    icon.classList.add("closed");
    body.style.display = "none";
    Shiny.setInputValue(id + "_click", "closed", { priority: "event" });
  }
  if (state === "open" && isClosed) {
    container.classList.remove("closed");
    icon.classList.remove("closed");
    body.style.display = "block";
    Shiny.setInputValue(id + "_click", "open", { priority: "event" });
  }
});


// =============================================================================
// 6. FILTROS DOS GRÁFICOS (DROPDOWN DE FILTROS NOS CARDS E NA HOME)
//    Gerencia a abertura e o fechamento dos painéis de filtro flutuantes
//    (.filter-dropdown) presentes nos cards de visualização, na sidebar e na Home,
//    garantindo que apenas um fique aberto por vez. O posicionamento é
//    controlado nativamente via CSS (position: absolute em relação ao botão).
// =============================================================================

// Abrindo ou fechando o dropdown de filtros ao clicar no botão .div-botao-filtros
$(document).on('click', '.div-botao-filtros', function(e) {

  // Botões desabilitados (ex: filtros rápidos com a cadeia de localização
  // ainda incompleta) não devem abrir o dropdown.
  if (this.disabled || $(this).hasClass('disabled')) {
    return;
  }

  // Ignorando cliques que ocorrem dentro do conteúdo do dropdown (checkboxes, etc.)
  if ($(e.target).closest('.filter-dropdown').length) {
    return;
  }

  // No botão "+" dos filtros rápidos, o clique no próprio botão abre/fecha o
  // painel; cliques no conteúdo do dropdown não disparam abertura/fechamento.
  // Usa a classe (e não o id, que é namespaced na Home) para identificar o
  // trigger.
  if ($(this).hasClass('filtro-rapido-trigger') &&
      !$(e.target).closest('.filtro-rapido-trigger').length) {
    return;
  }

  e.stopPropagation();

  var $botao = $(this);
  var menu = $botao.find('.filter-dropdown');
  var isOpen = menu.hasClass('show');

  // Fechando outros dropdowns abertos e removendo o estado ativo deles
  $('.filter-dropdown.show').not(menu).each(function() {
    var that = $(this);
    var trigger = that.closest('.div-botao-filtros');
    trigger.removeClass('active');
    trigger.find('.filtro-rapido-abrir').removeClass('active');
    that.removeClass('show').addClass('hide');
    setTimeout(function() {
      that.hide().removeClass('hide');
    }, 150);
  });

  if (!isOpen) {
    // Abrindo o dropdown e marcando o botão como ativo
    $botao.addClass('active');
    $botao.find('.filtro-rapido-abrir').addClass('active');
    menu.show(0, function() {
      $(this).addClass('show');
    });
  } else {
    // Fechando o dropdown e removendo o estado ativo do botão
    $botao.removeClass('active');
    $botao.find('.filtro-rapido-abrir').removeClass('active');
    menu.removeClass('show').addClass('hide');
    setTimeout(function() {
      menu.hide().removeClass('hide');
    }, 150);
  }
});

// Fechando todos os dropdowns de filtros ao clicar fora deles
$(document).on('click', function(e) {
  if (!$(e.target).closest('.div-botao-filtros').length) {
    $('.filter-dropdown.show').each(function() {
      var menu = $(this);
      var trigger = menu.closest('.div-botao-filtros');
      trigger.removeClass('active');
      trigger.find('.filtro-rapido-abrir').removeClass('active');
      menu.removeClass('show').addClass('hide');
      setTimeout(function() {
        menu.hide().removeClass('hide');
      }, 150);
    });
  }
});


// =============================================================================
// Pílula "Todas selecionadas" (maxValuesShown)
// Quando todas as opções válidas (não desabilitadas) de um select múltiplo
// estão selecionadas, troca o texto da pílula para "Todas selecionadas (N)"
// (ou "Todos selecionados (N)"), cobrindo tanto .ss-max (>= 2 selecionadas)
// quanto .ss-value (.ss-value-text quando há apenas 1 opção válida selecionada).
// =============================================================================
(function() {
  var TEXTOS_TODOS_SELECIONADOS = {
    input_filtro_rapido_categorias: 'Todas selecionadas',
    input_filtro_rapido_naturezas: 'Todas selecionadas',
    home_input_filtro_rapido_categorias: 'Todas selecionadas',
    home_input_filtro_rapido_naturezas: 'Todas selecionadas',
    input_hospital_multiplo: 'Todos selecionados',
    home_input_hospital_multiplo: 'Todos selecionados',
    input_momentos_do_obito: 'Todos selecionados',
    input_momentos_do_obito_fetais: 'Todos selecionados',
    input_momentos_do_obito_neonatais: 'Todos selecionados',
    input_momentos_do_obito_perinatais: 'Todos selecionados',
    input_faixas_de_peso: 'Todas selecionadas',
    input_idade_bebe: 'Todas selecionadas',
    input_faixas_de_ig: 'Todas selecionadas'
  };

  // Os selects da Home têm ids namespaced (ex.: "home_1-home_input_hospital_multiplo");
  // o texto da pílula é resolvido por sufixo do id para cobrir os dois contextos.
  function textoTodosSelecionados(selectId) {
    var chave = String(selectId || '').replace(/^.*-/, '');
    var base = TEXTOS_TODOS_SELECIONADOS[chave] || TEXTOS_TODOS_SELECIONADOS[selectId];
    if (base) return base;
    if (chave.indexOf('hospital_multiplo') !== -1) return 'Todos selecionados';
    if (chave.indexOf('momentos_do_obito') !== -1) return 'Todos selecionados';
    if (chave.indexOf('filtro_rapido_') !== -1) return 'Todas selecionadas';
    return 'Todas selecionadas';
  }

  // Inputs que nunca recebem a pílula "Todas selecionadas": exibem sempre as
  // chips individuais. Chave = sufixo do id (namespace do módulo ignorado),
  // mesma convenção do bloco "Selecionar todos" (6B).
  var IDS_SEM_PILULA_TODOS = {
    input_scatter_anos: true,
    input_categorias_comparacao: true
  };

  function semPilulaTodos(selectId) {
    var chave = String(selectId || '').replace(/^.*-/, '');
    return IDS_SEM_PILULA_TODOS[chave] === true;
  }

  function aplicarTextoMax(values, select) {
    if (!values || !select) return;
    if (semPilulaTodos(select.id)) return;

    var total = 0;
    for (var i = 0; i < select.options.length; i++) {
      if (!select.options[i].disabled) total++;
    }
    var selecionados = select.selectedOptions.length;
    var todosSelecionados = total > 0 && selecionados === total;

    if (todosSelecionados) {
      var texto = textoTodosSelecionados(select.id) + ' (' + selecionados + ')';
      // A prova é sempre o texto visível, nunca um marcador guardado: o
      // slim-select redesenha a pílula a cada setSelected (mesmo quando a
      // seleção não muda), apagando o nosso texto. Um marcador diria
      // "já aplicado" e pularia a escrita — foi exatamente essa regressão.
      // Sem escrita, sem nova mutação: quando o texto já está certo, esta
      // função vira no-op e o observador estabiliza sozinho.
      var max = values.querySelector('.ss-max');
      if (max) {
        if (max.textContent !== texto) {
          max.textContent = texto;
        }
        return;
      }
      var valuesList = values.querySelectorAll('.ss-value');
      if (valuesList.length > 0) {
        var maxEl = document.createElement('div');
        maxEl.className = 'ss-max';
        maxEl.textContent = texto;
        values.innerHTML = '';
        values.appendChild(maxEl);
        return;
      }
    }
  }

  function observarSelectMax(select) {
    if (select.dataset.phMaxObserver) return;
    select.dataset.phMaxObserver = '1';

    var main = select.nextElementSibling;
    if (!main || !main.classList.contains('ss-main')) return;

    var values = main.querySelector('.ss-values');
    if (!values) return;

    // Um único observador no contêiner da pílula (.ss-values), que é o que o
    // slim-select redesenha a cada mudança visível. O observador antigo nas
    // options do select nativo foi removido: durante a cascata ele disparava a
    // cada reconstrução de opções, e a troca pelo usuário chega pelo `change`.
    var observer = new MutationObserver(function() {
      aplicarTextoMax(values, select);
    });
    observer.observe(values, { childList: true, subtree: true, characterData: true });

    select.addEventListener('change', function() {
      aplicarTextoMax(values, select);
    });

    aplicarTextoMax(values, select);
  }

  function iniciarObservadoresMax() {
    var pendentes = false;
    document.querySelectorAll('select[multiple].slim-select').forEach(function(select) {
      if (semPilulaTodos(select.id)) return;
      var main = select.nextElementSibling;
      if (!main || !main.classList.contains('ss-main')) {
        pendentes = true;
        return;
      }
      observarSelectMax(select);
    });

    // Os .ss-main são criados quando o Shiny inicializa os bindings; enquanto
    // algum select ainda não tiver o seu, agenda uma nova tentativa.
    if (pendentes) {
      setTimeout(iniciarObservadoresMax, 250);
    }
  }

  $(document).on('shiny:sessioninitialized', iniciarObservadoresMax);
  if (document.readyState !== 'loading') {
    setTimeout(iniciarObservadoresMax, 500);
  }
})();


// =============================================================================
// 6B. SLIMSELECTS MÚLTIPLOS — "SELECIONAR TODOS" GLOBAL NO DROPDOWN
//     O slim-select embutido no shinyWidgets 0.9.1 não suporta um "select all"
//     global via settings (só por optgroup). Para todos os selects múltiplos
//     do app, injeta no topo do .ss-list uma linha "Selecionar todos(as)"
//     espelhando o visual dos checkboxes por natureza. Como o slim-select
//     limpa e reconstrói o .ss-list a cada renderOptions (abertura, busca e
//     updateSlimSelect), um MutationObserver por select garante a reinjeção e
//     a atualização do estado. Opções disabled (universo completo dos filtros
//     rápidos) não contam nem são selecionadas. Se um upgrade do shinyWidgets
//     expuser selectAll global via settings, este bloco pode ser substituído
//     por slimSelectInput(..., selectAll = TRUE).
// =============================================================================
(function() {
  var SELECTOR_MULTIPLOS = 'select[multiple].slim-select';

  // Inputs que não devem receber a linha. input_categorias_comparacao pede
  // exatamente duas naturezas (maxSelected = 2); selecionar tudo viola a
  // semântica do input.
  var IDS_EXCLUIDOS = {
    input_categorias_comparacao: true
  };

  // Rótulo da linha por input (a chave é o sufixo do id, ignorando o
  // namespace do módulo Shiny, ex: "indicadores_1-input_scatter_anos").
  var TEXTOS_SELECIONAR_TODOS = {
    input_filtro_rapido_categorias: 'Selecionar todas',
    input_filtro_rapido_naturezas: 'Selecionar todas',
    home_input_filtro_rapido_categorias: 'Selecionar todas',
    home_input_filtro_rapido_naturezas: 'Selecionar todas',
    input_hospital_multiplo: 'Selecionar todos',
    home_input_hospital_multiplo: 'Selecionar todos',
    input_momentos_do_obito: 'Selecionar todos',
    input_momentos_do_obito_fetais: 'Selecionar todos',
    input_momentos_do_obito_neonatais: 'Selecionar todos',
    input_momentos_do_obito_perinatais: 'Selecionar todos',
    input_faixas_de_peso: 'Selecionar todas',
    input_idade_bebe: 'Selecionar todas',
    input_faixas_de_ig: 'Selecionar todas'
  };

  function chaveInput(id) {
    return String(id).replace(/^.*-/, '');
  }

  function estaExcluido(id) {
    return IDS_EXCLUIDOS[chaveInput(id)] === true;
  }

  function rotuloSelecionarTodos(id) {
    return TEXTOS_SELECIONAR_TODOS[chaveInput(id)] || 'Selecionar todos';
  }

  // Elemento que contém o dropdown (onde o slim-select anexa o .ss-content
  // via contentLocation). Segue a convenção "{id}_wrapper" usada no app.
  function obterWrapper(select) {
    var wrapper = document.getElementById(select.id + '_wrapper');
    if (wrapper) return wrapper;
    var slim = select.slim;
    if (slim && slim.render && slim.render.content && slim.render.content.main) {
      var pai = slim.render.content.main.parentElement;
      if (pai && pai !== document.body) return pai;
    }
    return null;
  }

  function obterList(select) {
    var wrapper = obterWrapper(select);
    if (!wrapper) return null;
    return wrapper.querySelector('.ss-content .ss-list');
  }

  function opcoesHabilitadas(select) {
    var resultado = [];
    for (var i = 0; i < select.options.length; i++) {
      if (!select.options[i].disabled) {
        resultado.push(select.options[i]);
      }
    }
    return resultado;
  }

  function montarLinhaSelecionarTodos(select) {
    var linha = document.createElement('div');
    linha.className = 'ss-selectall-global';

    var rotulo = document.createElement('span');
    rotulo.textContent = rotuloSelecionarTodos(select.id);
    linha.appendChild(rotulo);

    var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', '0 0 100 100');
    var box = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    box.setAttribute('d', 'M60,10 L10,10 L10,90 L90,90 L90,50');
    var check = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    check.setAttribute('d', 'M30,45 L50,70 L90,10');
    svg.appendChild(box);
    svg.appendChild(check);
    linha.appendChild(svg);

    // Listener no próprio elemento, como nos checkboxes nativos de optgroup:
    // o stopPropagation na origem impede o documentClick do slim-select de
    // rodar. Se ele rodasse depois do setSelected (que reconstrói o .ss-list
    // de forma síncrona e desanexa o alvo do clique), o teste de contenção
    // falharia e o dropdown fecharia.
    linha.addEventListener('click', function(e) {
      e.preventDefault();
      e.stopPropagation();

      if (!select.slim) return;

      var habilitadas = opcoesHabilitadas(select);
      if (habilitadas.length === 0) return;

      var todasSelecionadas = habilitadas.every(function(opt) {
        return opt.selected;
      });

      // Alterna: tudo selecionado -> limpa; senão -> seleciona as habilitadas.
      var valores = todasSelecionadas
        ? []
        : habilitadas.map(function(opt) {
            return opt.value;
          });

      // Mesmo padrão de reset_ui_slim (el.slim.setSelected + change com
      // bubbles) para sincronizar o slim-select e notificar o Shiny.
      select.slim.setSelected(valores);
      select.dispatchEvent(new Event('change', { bubbles: true }));
    });

    return linha;
  }

  function atualizarEstadoSelecionarTodos(select, linha) {
    var habilitadas = opcoesHabilitadas(select);

    // Sem opções habilitadas (ex: nível estabelecimento): linha oculta.
    if (habilitadas.length === 0) {
      linha.style.display = 'none';
      return;
    }
    linha.style.display = '';

    var selecionadas = 0;
    for (var i = 0; i < habilitadas.length; i++) {
      if (habilitadas[i].selected) selecionadas++;
    }

    linha.classList.toggle('ss-selected', selecionadas === habilitadas.length);
    linha.classList.toggle('ss-partial', selecionadas > 0 && selecionadas < habilitadas.length);
  }

  function sincronizarSelecionarTodosGlobal(select) {
    var list = obterList(select);
    if (!list) return;

    var linha = list.querySelector('.ss-selectall-global');
    if (!linha) {
      linha = montarLinhaSelecionarTodos(select);
      list.insertBefore(linha, list.firstChild);
    }

    atualizarEstadoSelecionarTodos(select, linha);
  }

  function agendarSincronizacao(select) {
    if (select.__phSelecionarTodosFrame) return;
    select.__phSelecionarTodosFrame = requestAnimationFrame(function() {
      select.__phSelecionarTodosFrame = null;
      sincronizarSelecionarTodosGlobal(select);
    });
  }

  function iniciarObserverSelecionarTodos(select) {
    if (select.__phSelecionarTodosObserver) return;
    var wrapper = obterWrapper(select);
    if (!wrapper) return;
    select.__phSelecionarTodosObserver = true;

    var observer = new MutationObserver(function() {
      agendarSincronizacao(select);
    });
    observer.observe(wrapper, {
      childList: true,
      subtree: true,
      attributes: true,
      characterData: true
    });

    sincronizarSelecionarTodosGlobal(select);
  }

  function varrerSelectsMultiplos() {
    var pendentes = false;
    document.querySelectorAll(SELECTOR_MULTIPLOS).forEach(function(select) {
      if (estaExcluido(select.id)) return;
      if (!select.slim || !obterList(select)) {
        pendentes = true;
        return;
      }
      iniciarObserverSelecionarTodos(select);
    });

    // Os .ss-content são criados quando o Shiny inicializa os bindings; os
    // selects de módulos podem surgir depois (ex: scatter na aba Indicadores).
    if (pendentes) {
      setTimeout(varrerSelectsMultiplos, 250);
    }
  }

  $(document).on('shiny:sessioninitialized', function() {
    setTimeout(varrerSelectsMultiplos, 500);
  });
  if (document.readyState !== 'loading') {
    setTimeout(varrerSelectsMultiplos, 500);
  }

  // Salvaguarda: se o Shiny recriar um select (novo elemento), reinicia.
  $(document).on('shiny:value', function() {
    setTimeout(varrerSelectsMultiplos, 100);
  });
})();


// =============================================================================
// 7. MÓDULO DE INDICADORES — GRÁFICO DE BARRAS
//    Evita conflito de seleção entre a comparação principal (radio button) e
//    as comparações adicionais (checkboxes) no gráfico de barras do módulo
//    mod_indicadores: desabilita o checkbox cujo valor já está selecionado
//    como comparação principal.
// =============================================================================

// Gerenciando o conflito entre input_barras_comparacao_principal e
// input_barras_comparacoes_adicionais após a conexão do Shiny
$(document).on('shiny:connected', function() {

  // Desabilitando o checkbox que coincide com a comparação principal selecionada
  function gerenciarConflitoComparacao() {
    // Se o input de comparação principal está oculto (modo comparação por
    // grupos ativo), não desabilitar nenhuma opção adicional — o conflito
    // deixa de existir porque o input principal está fora do layout.
    if (!$('input[name$="input_barras_comparacao_principal"]:visible').length) {
      $('input[name$="input_barras_comparacoes_adicionais"]').prop('disabled', false)
        .closest('label').css({'opacity': '1', 'cursor': 'pointer'});
      return;
    }

    // O seletor [name$='...'] ignora o namespace do módulo Shiny
    var principal = $('input[name$="input_barras_comparacao_principal"]:checked').val();

    $('input[name$="input_barras_comparacoes_adicionais"]').each(function() {
      var box = $(this);

      if (box.val() == principal) {
        // Desmarcando se estava marcado e notificando o Shiny da mudança
        if (box.prop('checked')) {
          box.prop('checked', false);
          box.trigger('change');
        }
        // Desabilitando visualmente o item conflitante
        box.prop('disabled', true);
        box.closest('label').css('opacity', '0.5').css('cursor', 'not-allowed');
      } else {
        // Reabilitando os demais itens
        box.prop('disabled', false);
        box.closest('label').css('opacity', '1').css('cursor', 'pointer');
      }
    });
  }

  // Reaplicando a lógica sempre que o radio button de comparação principal mudar
  $(document).on('change', 'input[name$="input_barras_comparacao_principal"]', function() {
    gerenciarConflitoComparacao();
  });

  // Reaplicando a lógica quando o Shiny atualizar os inputs dinamicamente
  // (ex: mudança de nível de análise que altera o selected via update*Input).
  // Sem este listener, o bloqueio visual só era aplicado após a primeira
  // interação manual do usuário com o radio de comparação principal.
  $(document).on('shiny:inputchanged', function(event) {
    var name = event.name || '';
    if (name.indexOf('input_barras_comparacao_principal') !== -1 ||
        name.indexOf('input_barras_comparacoes_adicionais') !== -1) {
      // Pequeno delay para garantir que o DOM do Shiny já foi atualizado
      setTimeout(gerenciarConflitoComparacao, 50);
    }
  });

  // Aplicando o estado inicial após o DOM do Shiny estar completamente carregado
  setTimeout(gerenciarConflitoComparacao, 100);
});


// =============================================================================
// 7B. MÓDULO DE COMPARAÇÃO POR GRUPOS — DESABILITAR OPÇÕES DINAMICAMENTE
//    O updatePrettyRadioButtons recria o DOM de forma assíncrona via WebSocket,
//    o que cria race condition com JS inline executado no mesmo batch. Solução:
//    o server armazena os valores a desabilitar em `data-ph-disabled` no
//    container, e um MutationObserver detecta quando o `.shiny-options-group`
//    é recriado e reaplica o `disabled` de forma determinística (mesma
//    abordagem do helper `atualizar_input_desejo_visualizar` que funciona).
// =============================================================================

// Aplicando disabled nas opções de um prettyRadioButtons conforme o atributo
// data-ph-disabled do container. Chamada após cada recriação do DOM pelo
// updatePrettyRadioButtons (via MutationObserver) e também diretamente pelo
// server quando necessário. Parâmetros:
//   - containerId: id do container do prettyRadioButtons;
//   - defaultValor: valor a forçar quando uma opção desabilitada está
//     selecionada (ex.: "nao_comparar" para comparação, "publico" para
//     financiamento).
window.phAplicarDesabilitarRadio = function(containerId, defaultValor) {
  var container = document.getElementById(containerId);
  if (!container) return;
  var raw = container.getAttribute('data-ph-disabled');
  var desabilitados = {};
  if (raw) {
    try {
      desabilitados = JSON.parse(raw) || {};
    } catch (e) {
      desabilitados = {};
    }
  }

  // Reabilita todos os inputs antes de aplicar o estado atual
  var todos = container.querySelectorAll('input[type="radio"]');
  for (var i = 0; i < todos.length; i++) {
    todos[i].disabled = false;
    var p = todos[i].closest('.pretty, .radio, .form-group');
    if (p) p.removeAttribute('title');
  }

  // Aplica disabled + tooltip nos inputs cuja valor está em desabilitados
  Object.keys(desabilitados).forEach(function(valor) {
    var radio = container.querySelector('input[type="radio"][value="' + valor + '"]');
    if (!radio) return;
    // Se a opção que será desabilitada está atualmente selecionada,
    // força a mudança para o default antes de desabilitar.
    if (radio.checked) {
      radio.checked = false;
      var radioDefault = container.querySelector('input[type="radio"][value="' + defaultValor + '"]');
      if (radioDefault) {
        radioDefault.checked = true;
        if (typeof jQuery !== 'undefined') {
          jQuery(radioDefault).trigger('change');
        } else {
          radioDefault.dispatchEvent(new Event('change', { bubbles: true }));
        }
      }
      if (window.Shiny && typeof window.Shiny.setInputValue === 'function') {
        window.Shiny.setInputValue(containerId, defaultValor, {priority: 'event'});
      }
    }
    radio.disabled = true;
    var prettyWrapper = radio.closest('.pretty, .radio, .form-group');
    if (prettyWrapper) prettyWrapper.setAttribute('title', desabilitados[valor]);
  });
};

// Compatibilidade: a comparação usa o mecanismo genérico com default
// "nao_comparar" (a opção desabilitada selecionada volta para "Não comparar").
window.phAplicarDesabilitarComparacao = function() {
  window.phAplicarDesabilitarRadio('input_desejo_comparar', 'nao_comparar');
};

// Registrando MutationObservers para reaplicar disabled após recriação do DOM
$(document).on('shiny:connected', function() {
  var registrarObserver = function(containerId, fnAplicar) {
    var container = document.getElementById(containerId);
    if (!container || container._phObserverRegistrado) return;
    container._phObserverRegistrado = true;

    var observer = new MutationObserver(function(mutations) {
      for (var i = 0; i < mutations.length; i++) {
        var added = mutations[i].addedNodes;
        for (var j = 0; j < added.length; j++) {
          var n = added[j];
          if (n.nodeType === 1 && n.classList && n.classList.contains('shiny-options-group')) {
            if (typeof fnAplicar === 'function') fnAplicar();
            return;
          }
        }
      }
    });
    observer.observe(container, { childList: true, subtree: true });
  };

  registrarObserver('input_desejo_comparar', window.phAplicarDesabilitarComparacao);
  registrarObserver('input_financiamento', function() {
    window.phAplicarDesabilitarRadio('input_financiamento', 'publico');
  });
});


// =============================================================================
// 7C. FILTROS RÁPIDOS + COMPARAÇÃO — TOOLTIP DAS OPÇÕES DESABILITADAS
//     Os slimSelects de categorias/naturezas (filtros rápidos) e do
//     input_categorias_comparacao exibem o universo completo de opções; as
//     inválidas para o contexto atual chegam com `disabled: true` (classe
//     .ss-disabled gerenciada pelo SlimSelect). Como o SlimSelect não possui
//     título nativo por opção, o `title` é aplicado via delegação de eventos
//     no primeiro hover (as opções só existem no DOM enquanto o dropdown está
//     aberto).
//     No input de comparação o servidor envia a tooltip por opção via
//     `data$tooltip`. IMPORTANTE: o renderer do slim-select embutido no
//     shinyWidgets 0.9.1 copia o campo `data` da opção APENAS para a <option>
//     nativa oculta (data-tooltip) — o div .ss-option renderizado não recebe
//     os atributos. Como o div expõe o mesmo id da option nativa (t.id =
//     e.id nos dois), a tooltip é lida da <option> correspondente. O texto
//     depende da fonte do indicador (SIH: "entre os públicos e mistos
//     selecionados" + texto próprio para "Privado"; não-SIH: "entre os
//     selecionados"). Os filtros rápidos mantêm o texto genérico por input.
// =============================================================================

// Tooltip da opção do input_categorias_comparacao: lê o atributo data-tooltip
// da <option> nativa correspondente ao div (.ss-option). Retorna null quando
// não há tooltip (opção habilitada / input sem options / ids divergentes).
function tooltipOpcaoComparacao($opt) {
  var id = $opt.attr('data-id');
  if (!id) return null;
  var select = document.getElementById('input_categorias_comparacao');
  if (!select) return null;
  for (var i = 0; i < select.options.length; i++) {
    if (select.options[i].id === id) {
      return select.options[i].getAttribute('data-tooltip');
    }
  }
  return null;
}

$(document).on('mouseover',
  '#input_filtro_rapido_categorias_wrapper .ss-option.ss-disabled, ' +
  '#input_filtro_rapido_naturezas_wrapper .ss-option.ss-disabled, ' +
  '#input_categorias_comparacao_wrapper .ss-option.ss-disabled',
  function() {
    var $opt = $(this);
    if ($opt.attr('title')) return;

    if ($opt.closest('#input_categorias_comparacao_wrapper').length > 0) {
      var tip = tooltipOpcaoComparacao($opt);
      if (tip) {
        $opt.attr('title', tip);
        return;
      }
    }

    var emCategorias = $opt.closest('#input_filtro_rapido_categorias_wrapper').length > 0;
    $opt.attr('title', emCategorias
      ? 'Sem hospitais desta categoria no escopo selecionado'
      : 'Sem hospitais desta natureza no escopo selecionado');
  }
);


// =============================================================================
// 8. INPUTS PERSONALIZADOS (SELECTIZE E VIRTUAL SELECT)
//    Ajustes de comportamento para os inputs customizados usados nos filtros:
//    - syncWidth: alinha a largura do dropdown do selectize ao input de origem
// =============================================================================

// Sincronizando a largura do dropdown do selectize com o próprio input de origem
function syncWidth(id) {
  var sel = $('#' + id)[0];
  if (!sel) return;
  var s = sel.selectize;
  if (!s) return;

  function setWidth() {
    var w = s.$control.outerWidth();
    setTimeout(function() {
      s.$dropdown.css({
        width: w + 'px',
        minWidth: w + 'px',
        maxWidth: w + 'px'
      });
    }, 0);
  }
  s.on('dropdown_open', setWidth);
  $(window).on('resize', setWidth);
}

// Inicializando a sincronização de largura para o input_categoria ao conectar
$(document).on('shiny:connected shiny:inputchanged', function(e) {
  if (e.name === 'input_categoria' || e.type === 'shiny:connected') {
    syncWidth('input_categoria');
  }
});

// Direção automática dos slimSelectInputs com contentPosition = "relative".
// O slim-select ignora openPosition = "auto" quando o contentLocation não é o
// body (chamando sempre moveContentBelow). Este MutationObserver detecta quando
// o dropdown abre e recalcula a direção com base no espaço disponível no
// contêiner visível (card/viewport), forçando ss-open-above quando necessário.
(function() {
  var SS_CONTENT_HEIGHT_DEFAULT = 300;
  var VIEWPORT_MARGIN = 8;

  function getConstraintRect(el) {
    var current = el.parentElement;

    while (current && current !== document.body) {
      var style = window.getComputedStyle(current);
      var overflowY = style.overflowY;
      var overflow = style.overflow;
      var clipsY = /(auto|scroll|hidden|clip)/.test(overflowY);
      var clipsBoth = /(auto|scroll|hidden|clip)/.test(overflow);

      if (clipsY || clipsBoth) {
        var rect = current.getBoundingClientRect();
        if (rect.height > 0) {
          return {
            top: rect.top + VIEWPORT_MARGIN,
            bottom: rect.bottom - VIEWPORT_MARGIN
          };
        }
      }

      current = current.parentElement;
    }

    return {
      top: VIEWPORT_MARGIN,
      bottom: window.innerHeight - VIEWPORT_MARGIN
    };
  }

  function getContentHeight(ssContent) {
    var contentH = ssContent.offsetHeight;

    if (contentH < 10) {
      contentH = ssContent.scrollHeight;
    }

    if (contentH < 10) {
      contentH = SS_CONTENT_HEIGHT_DEFAULT;
    }

    return contentH;
  }

  function getMainFromContent(ssContent) {
    if (!ssContent || !ssContent.parentElement) return null;

    var contentId = ssContent.getAttribute('data-id');
    var mains = ssContent.parentElement.querySelectorAll('.ss-main');

    for (var i = 0; i < mains.length; i++) {
      if (!contentId || mains[i].getAttribute('data-id') === contentId) {
        return mains[i];
      }
    }

    var prev = ssContent.previousElementSibling;
    while (prev) {
      if (prev.classList && prev.classList.contains('ss-main')) {
        return prev;
      }
      prev = prev.previousElementSibling;
    }

    return null;
  }

  function applySlimSelectDirection(ssContent) {
    if (!ssContent || !ssContent.classList.contains('ss-content')) return;

    var ssMain = getMainFromContent(ssContent);
    if (!ssMain) return;

    // Durante o fechamento, não recalcula a direção para evitar "pulo" visual.
    // Mantém apenas o último âncora e remove margens inline que o SlimSelect injeta.
    var isExpanded = ssMain.getAttribute('aria-expanded') === 'true';
    if (!isExpanded) {
      ssContent.style.removeProperty('margin');
      return;
    }

    var mainRect = ssMain.getBoundingClientRect();
    var constraintRect = getConstraintRect(ssMain);
    var contentH = getContentHeight(ssContent);
    var spaceBelow = constraintRect.bottom - mainRect.bottom;
    var spaceAbove = mainRect.top - constraintRect.top;

    var isFiltroAdicional = !!(ssMain.closest && ssMain.closest('.filtro-adicional-dropdown')) ||
                             !!(ssContent.closest && ssContent.closest('.filtro-adicional-dropdown'));

    var isFiltroRapido = !isFiltroAdicional &&
                         (!!(ssMain.closest && ssMain.closest('.filtro-rapido-dropdown')) ||
                          !!(ssContent.closest && ssContent.closest('.filtro-rapido-dropdown')));

    var isHomeSelect = !isFiltroRapido && !isFiltroAdicional &&
                       (!!(ssMain.closest && ssMain.closest('.home-filter-card')) ||
                        !!(ssContent.closest && ssContent.closest('.home-filter-card')));

    // Frases de filtros inline nos rodapés dos gráficos (barras, linhas, pontos)
    // (.frase-filtro-inline): abre estritamente para CIMA, como na Home.
    var isFraseInline = (!!(ssMain.closest && ssMain.closest('.frase-filtro-inline')) ||
                         !!(ssContent.closest && ssContent.closest('.frase-filtro-inline')));

    // Para filtros rápidos (.filtro-rapido-dropdown, exceto filtros adicionais), abre estritamente para BAIXO.
    // Para os selects principais da Home (.home-filter-card) e da frase inline
    // (.frase-filtro-inline), abre estritamente para CIMA.
    // Filtros adicionais (.filtro-adicional-dropdown) e demais locais: AUTO (preferencialmente para BAIXO,
    // para CIMA quando faltar espaço).
    var shouldOpenAbove = isFiltroRapido ? false : (isHomeSelect || isFraseInline || ((spaceBelow < contentH) && (spaceAbove > spaceBelow)));
    var direction = shouldOpenAbove ? 'above' : 'below';

    ssMain.setAttribute('data-ss-last-direction', direction);
    ssContent.setAttribute('data-ss-last-direction', direction);

    ssMain.classList.toggle('ss-open-above', shouldOpenAbove);
    ssMain.classList.toggle('ss-open-below', !shouldOpenAbove);
    ssContent.classList.toggle('ss-open-above', shouldOpenAbove);
    ssContent.classList.toggle('ss-open-below', !shouldOpenAbove);

    // Remove estilos inline legados para deixar o CSS por classe controlar posição.
    ssContent.style.removeProperty('top');
    ssContent.style.removeProperty('bottom');
    ssContent.style.removeProperty('margin');
  }

  function scheduleSlimSelectDirection(ssContent) {
    if (!ssContent) return;

    requestAnimationFrame(function() {
      applySlimSelectDirection(ssContent);
      setTimeout(function() {
        applySlimSelectDirection(ssContent);
      }, 0);
    });
  }

  function getContentFromMain(mainEl) {
    if (!mainEl || !mainEl.parentElement) return null;

    var mainId = mainEl.getAttribute('data-id');
    var contents = mainEl.parentElement.querySelectorAll('.ss-content');

    for (var i = 0; i < contents.length; i++) {
      if (!mainId || contents[i].getAttribute('data-id') === mainId) {
        return contents[i];
      }
    }

    return mainEl.parentElement.querySelector('.ss-content');
  }

  var slimSelectObserver = new MutationObserver(function(mutations) {
    mutations.forEach(function(mutation) {
      if (mutation.type === 'attributes' && mutation.attributeName === 'class') {
        var el = mutation.target;
        if (
          el.classList &&
          el.classList.contains('ss-content') &&
          (el.classList.contains('ss-open-below') || el.classList.contains('ss-open-above'))
        ) {
          scheduleSlimSelectDirection(el);
        }

        if (
          el.classList &&
          el.classList.contains('ss-main') &&
          (el.classList.contains('ss-open-below') || el.classList.contains('ss-open-above'))
        ) {
          var contentEl = getContentFromMain(el);
          if (contentEl) {
            scheduleSlimSelectDirection(contentEl);
          }
        }
      }

      if (mutation.type === 'childList') {
        mutation.addedNodes.forEach(function(node) {
          if (!(node instanceof HTMLElement)) return;

          if (node.classList.contains('ss-content')) {
            scheduleSlimSelectDirection(node);
            return;
          }

          node.querySelectorAll('.ss-content').forEach(function(nestedContent) {
            scheduleSlimSelectDirection(nestedContent);
          });
        });
      }
    });
  });

  $(document).on('click keydown focusin', '#card-filters .ss-main, .home-filter-card .ss-main, .frase-filtro-inline .ss-main', function(e) {
    if (e.type === 'keydown') {
      var key = e.key;
      if (key !== 'Enter' && key !== ' ' && key !== 'ArrowDown' && key !== 'ArrowUp') {
        return;
      }
    }

    var ssContent = getContentFromMain(this);
    if (ssContent) {
      scheduleSlimSelectDirection(ssContent);
    }
  });

  $(window).on('resize', function() {
    $('#card-filters .ss-content.ss-open-above, #card-filters .ss-content.ss-open-below, .home-filter-card .ss-content.ss-open-above, .home-filter-card .ss-content.ss-open-below').each(function() {
      scheduleSlimSelectDirection(this);
    });
  });

  $(document).on('scroll', '#card-filters .card-body', function() {
    $('#card-filters .ss-content.ss-open-above, #card-filters .ss-content.ss-open-below').each(function() {
      scheduleSlimSelectDirection(this);
    });
  });

  $(document).ready(function() {
    var filtersCard = document.getElementById('card-filters');
    if (filtersCard) {
      slimSelectObserver.observe(filtersCard, {
        attributes: true,
        attributeFilter: ['class'],
        childList: true,
        subtree: true
      });

      filtersCard.querySelectorAll('.ss-content').forEach(function(el) {
        if (el.classList.contains('ss-open-below') || el.classList.contains('ss-open-above')) {
          scheduleSlimSelectDirection(el);
        }
      });
    }

    // Home: o gerenciador de direção (isHomeSelect → acima) precisa observar o
    // .home-filter-card — sem isso o múltiplo ficava com ss-open-below (busca
    // no topo) enquanto o CSS forçava a posição visual acima.
    document.querySelectorAll('.home-filter-card').forEach(function(homeCard) {
      slimSelectObserver.observe(homeCard, {
        attributes: true,
        attributeFilter: ['class'],
        childList: true,
        subtree: true
      });

      homeCard.querySelectorAll('.ss-content').forEach(function(el) {
        if (el.classList.contains('ss-open-below') || el.classList.contains('ss-open-above')) {
          scheduleSlimSelectDirection(el);
        }
      });
    });

    // Frases de filtros inline (rodapés dos gráficos de barras, linhas e
    // pontos): o gerenciador de direção (isFraseInline → acima) precisa
    // observar o contêiner de cada output. O contêiner do uiOutput é estável
    // (só o conteúdo interno é recriado a cada render); se ainda não existir
    // no ready (aba nunca visitada), a observação é instalada na primeira
    // abertura via delegação de clique.
    var FRASE_INLINE_IDS = [
      'indicadores_1-frase_barras_inline',
      'indicadores_1-frase_linhas_inline',
      'indicadores_1-frase_scatter_inline'
    ];
    function fraseContainers() {
      return FRASE_INLINE_IDS
        .map(function(id) { return document.getElementById(id); })
        .filter(function(el) { return !!el; });
    }
    function observarFraseInline() {
      fraseContainers().forEach(function(fraseContainer) {
        if (fraseContainer.getAttribute('data-ss-observada') === '1') {
          return;
        }
        fraseContainer.setAttribute('data-ss-observada', '1');
        slimSelectObserver.observe(fraseContainer, {
          attributes: true,
          attributeFilter: ['class'],
          childList: true,
          subtree: true
        });
      });
    }
    observarFraseInline();
    $(document).on('click focusin', '.frase-filtro-inline .ss-main', function() {
      observarFraseInline();
    });

    // Anti-flash da frase inline: selects com contentLocation nascem abertos
    // no init e cada re-render repete o ciclo — até a primeira interação os
    // painéis ficam invisíveis (gate `html:not(.ph-frase-liberada)` no
    // custom.css). Libera no primeiro pointerdown (capture: abre DEPOIS,
    // já liberado) ou tecla de abertura; sem timeout de backstop — a frase
    // pode nascer minutos após o load (visita tardia à aba).
    function liberarFraseInline() {
      document.documentElement.classList.add('ph-frase-liberada');
    }
    // Trava auto-recarregável: a cada re-render da frase (novos binds, que
    // nascem abertos), o gate fecha de novo e só libera após assentar
    // (~500ms, cobre o fade) — com fechamento explícito dos que o hook de
    // initialize não pegou. Assim, visitas tardias à aba (gate já liberado
    // por cliques na Home) também nunca exibem dropdowns auto-abertos.
    var fraseAssentarTimer = null;
    function fecharFraseInline() {
      if (!window.Shiny || !Shiny.inputBindings || !Shiny.inputBindings.bindings) return;
      var conts = fraseContainers();
      if (!conts.length) return;
      Shiny.inputBindings.bindings.forEach(function(entry) {
        var b = entry && entry.binding;
        if (!b || b.name !== 'shinyWidgets.slimSelectBinding' || !b.store) return;
        for (var id in b.store) {
          if (!b.store.hasOwnProperty(id) || !b.store[id]) continue;
          var el = document.getElementById(id);
          var dentro = el && conts.some(function(cont) { return cont.contains(el); });
          if (dentro && typeof b.store[id].close === 'function') {
            try { b.store[id].close(); } catch (e) {}
          }
        }
      });
    }
    function prenderFraseInline() {
      document.documentElement.classList.remove('ph-frase-liberada');
      if (fraseAssentarTimer) clearTimeout(fraseAssentarTimer);
      fraseAssentarTimer = setTimeout(function() {
        fraseAssentarTimer = null;
        fecharFraseInline();
        liberarFraseInline();
      }, 500);
    }
    function fraseMutacaoEhRebind(mutation) {
      var checar = function(no) {
        return no instanceof HTMLElement &&
          (no.classList.contains('ss-main') || no.classList.contains('ss-content') ||
           no.querySelector('.ss-main, .ss-content'));
      };
      var i;
      for (i = 0; i < mutation.addedNodes.length; i++) {
        if (checar(mutation.addedNodes[i])) return true;
      }
      for (i = 0; i < mutation.removedNodes.length; i++) {
        if (checar(mutation.removedNodes[i])) return true;
      }
      return false;
    }
    function instalarTravaFrase() {
      document.querySelectorAll('.graficos-panel-agrupado, .graficos-panel-individual').forEach(function(alvo) {
        if (!alvo || alvo.getAttribute('data-frase-trava') === '1') return;
        alvo.setAttribute('data-frase-trava', '1');
        new MutationObserver(function(muts) {
          for (var k = 0; k < muts.length; k++) {
            if (muts[k].type === 'childList' && fraseMutacaoEhRebind(muts[k])) {
              prenderFraseInline();
              break;
            }
          }
        }).observe(alvo, { childList: true, subtree: true });
      });
    }
    instalarTravaFrase();
    document.addEventListener('pointerdown', function() {
      if (document.documentElement.classList.contains('ph-frase-liberada')) return;
      liberarFraseInline();
    }, true);
    $(document).on('keydown', '.frase-filtro-inline .ss-main', function(e) {
      var key = e.key;
      if (key !== 'Enter' && key !== ' ' && key !== 'ArrowDown' && key !== 'ArrowUp') return;
      liberarFraseInline();
    });
  });
})();


// =============================================================================
// 8B. CARD FILTROS — HELPERS COMPARTILHADOS DE ANIMAÇÃO
//     Funções utilitárias reutilizadas tanto pelo orquestrador de lote
//     (animarFiltrosCoordenado) quanto pela animação individual
//     (animarSlideIndividual). Centralizam a leitura do display original,
//     o cálculo de scroll e a limpeza de estado.
// =============================================================================

// Lendo o display computado do CSS e guardando em data('ph-original-display').
// Necessário porque jQuery usa 'block' como fallback no slideDown() quando o
// elemento tem display:none herdado de classes como .shinyjs-hide. Aceita
// também um data-ph-target-display explícito vindo do servidor.
function _phPreservarDisplayOriginal($el) {
  if ($el.data('ph-original-display')) return;

  var explicitTarget = $el.data('ph-target-display');
  if (explicitTarget) {
    $el.data('ph-original-display', explicitTarget);
    return;
  }

  var prevVisibility = $el.css('visibility');
  var prevDisplay = $el.css('display');
  var hadHideClass = $el.hasClass('shinyjs-hide');

  if (hadHideClass) $el.removeClass('shinyjs-hide');
  $el.css({visibility: 'hidden', display: ''});
  var actualDisplay = $el.css('display');

  $el.css({visibility: prevVisibility, display: prevDisplay});
  if (hadHideClass) $el.addClass('shinyjs-hide');

  $el.data('ph-original-display', actualDisplay);
}

// Calculando o scrollTop necessário para revelar um único elemento dentro do
// container. Retorna null se o elemento já está visível (sem necessidade de
// scroll). Usa a mesma regra de ouro do orquestrador: rola apenas o
// suficiente para deixar o novo conteúdo completamente visível.
function _phCalcularTargetTopScroll($el, $container, scrollMargin) {
  if (!$el || !$el.length || $el.outerHeight() === 0) return null;

  var cardTop = $container.offset().top;
  var cardBottom = cardTop + $container.innerHeight();
  var currentScrollTop = $container.scrollTop();
  var elTop = $el.offset().top;
  var elBottom = elTop + $el.outerHeight();

  if (elTop >= cardTop && elBottom <= cardBottom) {
    return currentScrollTop;
  }

  if (elTop < cardTop) {
    return currentScrollTop + (elTop - cardTop) - 15;
  }

  if (elBottom > cardBottom) {
    return currentScrollTop + (elBottom - cardBottom) + (scrollMargin || 20);
  }

  return currentScrollTop;
}

// Calculando o targetTop do scroll para um lote coordenado de animação.
// Usa a mesma REGRA DE OURO do orquestrador: o scroll é relativo ao(s)
// novo(s) input(s) aberto(s) nesta ação — o ÚLTIMO deles (maior base) é o
// alvo; nunca outros elementos já visíveis do card. Se nada está sendo
// aberto (caso de fallback), usa o último candidato visível do card.
// NOTA: os antigos #conditional_filtros_* (peso/momento/causa/idade/IG)
// foram removidos da lista de candidatos: vivem dentro do dropdown de
// filtros adicionais (position: fixed) e não participam do fluxo de scroll
// do card-body — medir seus offsets relativos ao container produziria
// alvos incorretos.
function _phCalcularTargetTopLote($container, $toShowConsiderar, scrollMargin) {
  var $show = $toShowConsiderar || $();
  var currentScrollTop = $container.scrollTop();

  // 1) PRIORIDADE: se há elementos sendo abertos nesta ação, calcular o
  //    scroll para trazer o ÚLTIMO deles para dentro da viewport.
  if ($show && $show.length) {
    var $abertos = $show.filter(function() {
      var $el = $(this);
      return $el.length && $el.outerHeight() > 0;
    });

    if ($abertos.length) {
      var $alvo = null;
      var baseAlvo = -Infinity;
      $abertos.each(function() {
        var $el = $(this);
        var baseAtual = $el.offset().top + $el.outerHeight();
        if (baseAtual > baseAlvo) {
          baseAlvo = baseAtual;
          $alvo = $el;
        }
      });

      var tTop = _phCalcularTargetTopScroll($alvo, $container, scrollMargin);
      if (tTop !== null && Math.abs(tTop - currentScrollTop) > 1) {
        return tTop;
      }
      // Se o novo input já está visível e não precisa de ajuste, retorna null
      // para sinalizar "sem scroll".
      return null;
    }
  }

  // 2) FALLBACK: se nenhum elemento está sendo aberto nesta ação, manter
  //    o comportamento de fallback usando a lista hardcoded (preserva a
  //    posição de elementos já visíveis).
  var candidatos = [
    $('#conditional_sub_bloco'),
    $('#conditional_desejo_visualizar'),
    $('#conditional_categoria'),
    $('#exclamacao_indicador').parent(),
    $('#conditional_filtros_adicionais'),
    $('#aviso_mortalidade_hospitalar_periodo'),
    $('#conditional_periodo'),
    $('#conditional_desejo_comparar'),
    $('#conditional_categorias_comparacao')
  ];

  var $alvoFallback = null;
  var baseAlvoFallback = -Infinity;
  candidatos.forEach(function(el) {
    var $el = $(el);
    if (!$el.length || $el.outerHeight() === 0) return;
    if (!$el.is(':visible')) return;
    var baseAtual = $el.offset().top + $el.outerHeight();
    if (baseAtual > baseAlvoFallback) {
      baseAlvoFallback = baseAtual;
      $alvoFallback = $el;
    }
  });

  if ($alvoFallback && $alvoFallback.length) {
    return _phCalcularTargetTopScroll($alvoFallback, $container, scrollMargin);
  }
  return null;
}

// =============================================================================
// 8B-1. CARD FILTROS — ANIMAÇÃO INDIVIDUAL DE SLIDE
//        Alterna a visibilidade de um único elemento do painel de filtros
//        usando a mesma transição de slide/scroll do orquestrador, mas
//        totalmente independente: não usa data-ph-action, não interfere
//        no token de lote e não exige coordenação com outros elementos.
//        É a forma genérica de animar inputs dinâmicos que respondem a
//        ações do usuário (ex.: clique em "Outras" para customizar peso,
//        momento, idade ou causa), sem acoplar sua animação ao lote de
//        troca de indicador.
// =============================================================================

// Animando um único elemento do painel de filtros com slide + scroll.
// opts: { selector, acao: 'show'|'hide', containerSelector, duration,
//         scrollMargin, enableScroll }
function animarSlideIndividual(opts) {
  opts = opts || {};
  var selector = opts.selector;
  var acao = opts.acao;
  var containerSelector = opts.containerSelector || '#card-filters .card-body';
  var duration = opts.duration || 300;
  var scrollMargin = opts.scrollMargin || 30;
  var enableScroll = opts.enableScroll !== false;

  if (!selector || (acao !== 'show' && acao !== 'hide')) return;

  var $el = $(selector);
  var $container = $(containerSelector);
  if (!$el.length || !$container.length) return;

  if (acao === 'hide') {
    if ($el.is(':visible')) {
      $el.stop(true, false).slideUp(duration, function() {
        $el.removeData('ph-original-display');
      });
    }
    return;
  }

  // acao === 'show'
  if ($el.is(':visible')) {
    // Se está visível mas em meio a uma animação de hide (slideUp),
    // precisamos cancelar essa animação para que o slideDown possa
    // assumir o controle. Caso contrário, o hide terminaria sozinho
    // e o container ficaria preso em display:none.
    if ($el.is(':animated')) {
      $el.stop(true, false);
    } else {
      return;
    }
  }

  _phPreservarDisplayOriginal($el);

  // Pré-cálculo do targetTop revelando temporariamente o elemento para
  // medir sua posição final antes de iniciar o slideDown.
  var targetTop = null;
  if (enableScroll) {
    var origDisplay = $el.data('ph-original-display') || '';
    var prevVis = $el.css('visibility');
    var prevDisp = $el.css('display');
    var hadHideClass = $el.hasClass('shinyjs-hide');

    if (hadHideClass) $el.removeClass('shinyjs-hide');
    $el.css({visibility: 'hidden', display: origDisplay || 'block'});
    $container[0].offsetHeight;
    $el[0].offsetHeight;

    targetTop = _phCalcularTargetTopScroll($el, $container, scrollMargin);

    $el.css({visibility: prevVis || '', display: prevDisp || ''});
    if (hadHideClass) $el.addClass('shinyjs-hide');
  }

  var restoredDisplay = $el.data('ph-original-display') || '';
  $el.removeClass('shinyjs-hide').hide();
  $el.stop(true, true).slideDown(duration, function() {
    $el.css('display', restoredDisplay);
  });

  if (enableScroll && targetTop !== null && Math.abs(targetTop - $container.scrollTop()) > 1) {
    $container.stop(true, false).animate({ scrollTop: targetTop }, duration);
  }
}


// =============================================================================
// 8B-2. CARD FILTROS — ANIMAÇÕES COORDENADAS DE TRANSIÇÃO
//        Orquestra as transições do painel de filtros (mostrar/ocultar seções
//        condicionais) em um único lote coordenado, evitando o "salto" causado
//        por múltiplas animações independentes competindo pelo controle do
//        scroll do card. Substitui o padrão de N chamadas sequenciais a
//        slideUp/slideDown + animate(scrollTop) por um pipeline de 4 fases:
//          1) Acumula chamadas do mesmo ciclo em um buffer único (lote atômico)
//          2) Fase Hide: todos os elementos com data-ph-action="hide" sobem
//          3) Fase Show: após Hide, todos com data-ph-action="show" descem
//          4) Fase Scroll: após o paint final (double requestAnimationFrame),
//             rola UMA única vez até o último elemento revelado
//        O scroll é calculado apenas quando o layout está realmente assentado,
//        eliminando os múltiplos movimentos do padrão anterior (scroll paralelo
//        ao slideDown + correção com setTimeout fixo).
// =============================================================================

// Acumulando chamadas de animação de um mesmo ciclo (vários runjs do Shiny
// processados no mesmo flush) e executando um ÚNICO lote consolidado no próximo
// frame. Chamadas posteriores que chegam enquanto um lote está em andamento são
// processadas em lote subsequente (nunca interrompem o lote vigente).
// Aceita opcionalmente coleções jQuery (paraEsconder/paraMostrar); caso
// contrário, coleta todos os elementos dentro do container marcados com
// data-ph-action="hide" ou data-ph-action="show".
function animarFiltrosCoordenado(opts) {
  opts = opts || {};
  var containerSelector = opts.containerSelector || '#card-filters .card-body';
  var enableScroll = opts.enableScroll !== false;
  var duration = opts.duration || 300;
  var scrollMargin = opts.scrollMargin || 40;
  var paraEsconder = opts.paraEsconder || null;
  var paraMostrar = opts.paraMostrar || null;

  var $container = $(containerSelector);
  if (!$container.length) return;

  // Coletando os elementos marcados e removendo os atributos imediatamente
  // para evitar reprocessamento caso a função seja chamada novamente.
  var $toHide = paraEsconder
    ? paraEsconder
    : $container.find('[data-ph-action="hide"]').removeAttr('data-ph-action');
  var $toShow = paraMostrar
    ? paraMostrar
    : $container.find('[data-ph-action="show"]').removeAttr('data-ph-action');

  if (!$toHide.length && !$toShow.length) {
    return;
  }

  // Buffer acumulativo por container: mensagens do servidor processadas no
  // mesmo ciclo são fundidas em um único lote. O scroll é habilitado se
  // QUALQUER chamada acumulada o solicitou — assim, na navegação entre
  // indicadores (Observer A com enableScroll=false + finalizar_navegacao_indicadores
  // com enableScroll=true) o scroll único final considera todos os elementos
  // revelados no lote consolidado.
  var pendentes = $container.data('ph-pendentes') || { hide: [], show: [] };
  pendentes.hide = pendentes.hide.concat($toHide.get());
  pendentes.show = pendentes.show.concat($toShow.get());
  $container.data('ph-pendentes', pendentes);
  $container.data('ph-enable-scroll', !!$container.data('ph-enable-scroll') || enableScroll);

  if (!$container.data('ph-lote-agendado')) {
    $container.data('ph-lote-agendado', true);
    requestAnimationFrame(function() {
      $container.removeData('ph-lote-agendado');
      _phExecutarLoteFiltros($container, duration, scrollMargin);
    });
  }
}

// Executando o lote consolidado de animações coordenadas em fases.
// Ao final, o scroll é aplicado uma ÚNICA vez, somente depois que o navegador
// conclui o layout/paint das animações (double requestAnimationFrame).
function _phExecutarLoteFiltros($container, duration, scrollMargin) {
  var pendentes = $container.data('ph-pendentes') || { hide: [], show: [] };
  var enableScroll = !!$container.data('ph-enable-scroll');
  $container.removeData('ph-pendentes').removeData('ph-enable-scroll');

  var $toHide = $(pendentes.hide);
  var $toShow = $(pendentes.show);

  if (!$toHide.length && !$toShow.length) {
    return;
  }

  // --- Fase 0a: Capturar o display original dos elementos a serem mostrados ---
  // Preserva valores como display: flex que jQuery não restaura sozinho após
  // um slideDown (jQuery usa 'block' como fallback quando o display computado
  // é 'none' por causa de classes como .shinyjs-hide). Aceita também um
  // data-ph-target-display explícito vindo do servidor.
  $toShow.each(function() {
    _phPreservarDisplayOriginal($(this));
  });

  // --- Fase 1: Esconder todos os elementos marcados ---
  // A scrollbar do card permanece visível durante toda a transição: o CSS
  // mantém overflow-y: auto + scrollbar-gutter: stable (espaço sempre
  // reservado), sem overflow-y: hidden — a barra nunca é "desligada".
  var hidePromises = $toHide.filter(':visible').map(function() {
    return $(this).stop(true, false).slideUp(duration).promise();
  }).get();

  var hideDeferred = hidePromises.length
    ? $.when.apply($, hidePromises)
    : $.Deferred().resolve().promise();

  hideDeferred.done(function() {
    // --- Fase 2: Mostrar todos os elementos marcados (sem scroll) ---
    var showPromises = $toShow.map(function() {
      var $el = $(this);
      if ($el.is(':visible')) {
        return $.Deferred().resolve().promise();
      }
      var origDisplay = $el.data('ph-original-display') || '';
      $el.removeClass('shinyjs-hide').hide();
      return $el.stop(true, true).slideDown(duration, function() {
        $el.css('display', origDisplay);
      }).promise();
    }).get();

    var showDeferred = showPromises.length
      ? $.when.apply($, showPromises)
      : $.Deferred().resolve().promise();

    showDeferred.done(function() {
      $toShow.removeData('ph-original-display');

      // --- Fase 3: Scroll ÚNICO pós-paint ---
      // O scroll é calculado SOMENTE depois que o navegador conclui o layout
      // e o paint das animações (double requestAnimationFrame): o primeiro rAF
      // garante que o frame das animações foi processado e o segundo que o
      // paint ocorreu, de modo que o targetTop usa as posições reais dos
      // widgets (incluindo ícones e estilos aplicados após o primeiro paint).
      if (!enableScroll) {
        return;
      }

      requestAnimationFrame(function() {
        requestAnimationFrame(function() {
          // Forçar reflow para garantir que o browser já calculou o layout
          // final dos widgets (especialmente na primeira renderização).
          $container[0].offsetHeight;
          // Usa $toShow como referência: o scroll pós-animação deve continuar
          // relativo ao(s) input(s) recém-aberto(s), nunca a outros elementos
          // visíveis mais abaixo no card.
          var novoTargetTop = _phCalcularTargetTopLote($container, $toShow, scrollMargin);
          if (novoTargetTop !== null) {
            var currentTop = $container.scrollTop();
            if (Math.abs(currentTop - novoTargetTop) > 1) {
                $container.stop(true, false).animate({ scrollTop: novoTargetTop }, 300);
            }
          }
        });
      });
    });
  });
}


// =============================================================================
// 9. MODAIS DO BOOTSTRAP
//    Corrige um bug do Shiny em que o modal deixa o scroll da página travado
//    e/ou backdrops residuais visíveis após ser fechado.
// =============================================================================

// Restaurando o scroll do body e removendo backdrops ao fechar qualquer modal
$(document).on('hidden.bs.modal', '.modal', function() {
  $('body').css({
    'overflow': 'auto',
    'height': 'auto',
    'padding-right': '0'
  }).removeClass('modal-open');

  // Removendo backdrops residuais que o Shiny às vezes deixa para trás
  $('.modal-backdrop').remove();
});

// Garantindo que o scroll do body seja bloqueado ao abrir qualquer modal.
// O Bootstrap adiciona .modal-open e overflow:hidden no body, mas o CSS
// customizado (.modal.show { display: flex !important } e
// .modal .modal-dialog { overflow: auto }) pode interferir quando o
// conteúdo do modal é alto (ex: visao geral agregada com highchart +
// reactable), fazendo o scroll vazar para o body. Este handler é uma
// proteção defensiva que reforça o bloqueio explicitamente.
$(document).on('shown.bs.modal', '.modal', function() {
  $('body').css({
    'overflow': 'hidden',
    'height': 'auto'
  }).addClass('modal-open');
});

// =============================================================================
// 9. PAGINA HOME
//    Alterna a classe .home-ativa no body (e no <html>) quando a aba "home"
//    esta ativa. Isso dispara os overrides de CSS da Home (fundo do
//    content-wrapper, barra de infos oculta, layout full-bleed). A classe já
//    nasce no <html> via script síncrono do <head> (app_ui) para valer desde o
//    primeiro paint; aqui ela é apenas mantida em sincronia ao trocar de aba.
// =============================================================================

// Aplicando .home-ativa no body ao trocar de aba
$(document).on('shiny:inputchanged', function(event) {
  if (event.name === 'abas') {
    if (event.value === 'home') {
      document.body.classList.add('home-ativa');
      document.documentElement.classList.add('home-ativa');
    } else {
      document.body.classList.remove('home-ativa');
      document.documentElement.classList.remove('home-ativa');
    }
  }
});

// Aplicando na carga inicial (home e a primeira aba, portanto e o estado default)
$(document).ready(function() {
  document.body.classList.add('home-ativa');
  document.documentElement.classList.add('home-ativa');
});


// =============================================================================
// 10. MOBILE — OCULTAMENTO DA BARRA AZUL E PAINEL DE FILTROS FLUTUANTE
//     Auto-oculta o .div-infos-principais ao rolar para baixo (≤ 1199px) e restaura
//     ao rolar para cima. Sincroniza a altura do spacer CSS. Gerencia a
//     abertura e o fechamento do painel lateral de filtros via FAB e backdrop.
// =============================================================================

// Altura da navbar guardada: só muda em resize/load, então medir uma vez por
// rodada de layout basta (antes cada rodada media 2 vezes + escrevia a var).
var _phAlturaNavbarCache = 0;

function atualizarAlturaNavbar() {
  var navbar = document.querySelector('.wrapper .main-header');
  if (!navbar) return;
  // ceil (não offsetHeight, que trunca): fração de px para baixo deixava
  // fresta de subpixel entre a navbar e a .div-infos-principais com o
  // conteúdo rolando por trás.
  var h = Math.ceil(navbar.getBoundingClientRect().height);
  if (h === _phAlturaNavbarCache) return;
  _phAlturaNavbarCache = h;
  document.documentElement.style.setProperty('--altura-navbar', h + 'px');
}

function alturaNavbarFixa() {
  if (_phAlturaNavbarCache > 0) return _phAlturaNavbarCache;
  var navbar = document.querySelector('.wrapper .main-header');
  return navbar ? Math.ceil(navbar.getBoundingClientRect().height) : 57;
}

// Última altura aplicada ao spacer: evita escrita de estilo (que invalida o
// layout) quando nada mudou.
var _phUltimoSpacerH = null;

// --- Sincroniza a altura do spacer com a altura real do div-infos-principais ---
function atualizarAlturaSpacer() {
  var barraInfos = document.querySelector('.div-infos-principais');
  var spacer = document.getElementById('div-infos-principais-spacer');
  if (!barraInfos || !spacer) return;
  var h = 0;
  if (window.innerWidth <= 1199) {
    // offsetHeight exclui a margin-bottom da barra (16px, fora do fluxo no
    // fixed): soma-se a margem para o spacer preservar o mesmo respiro.
    var margemBarra = parseFloat(window.getComputedStyle(barraInfos).marginBottom) || 0;
    h = barraInfos.offsetHeight + margemBarra;
  }
  if (h === _phUltimoSpacerH) return;
  _phUltimoSpacerH = h;
  if (h > 0) {
    document.documentElement.style.setProperty('--infos-principais-height', h + 'px');
    spacer.style.height = h + 'px';
  } else {
    spacer.style.height = '0px';
  }
}

window.addEventListener('load', function() { atualizarAlturaNavbar(); atualizarAlturaSpacer(); });
window.addEventListener('resize', function() { atualizarAlturaNavbar(); atualizarAlturaSpacer(); });
$(document).on('shiny:value', atualizarAlturaSpacer);

// --- Auto-hide do div-infos-principais ao rolar para baixo (somente mobile) ---
(function() {
  var lastScrollY = 0;
  var ticking = false;

  function atualizarVisibilidadeBarra() {
    var barraInfos = document.querySelector('.div-infos-principais');
    if (!barraInfos) { ticking = false; return; }

    if (window.innerWidth > 1199) {
      barraInfos.classList.remove('nav-scroll-hidden');
      ticking = false;
      return;
    }

    var currentY = window.scrollY;
    if (currentY > lastScrollY && currentY > 80) {
      barraInfos.classList.add('nav-scroll-hidden');
    } else {
      barraInfos.classList.remove('nav-scroll-hidden');
    }
    lastScrollY = currentY;
    ticking = false;
  }

  window.addEventListener('scroll', function() {
    if (!ticking) {
      requestAnimationFrame(atualizarVisibilidadeBarra);
      ticking = true;
    }
  }, { passive: true });

  window.addEventListener('resize', function() {
    var barraInfos = document.querySelector('.div-infos-principais');
    if (barraInfos && window.innerWidth > 1199) {
      barraInfos.classList.remove('nav-scroll-hidden');
    }
  });
})();

// --- Painel lateral de filtros (mobile): abrir, fechar e restaurar estado ---
function abrirFiltrosMobile() {
  document.body.classList.add('filtro-mobile-aberto');
  document.body.style.overflow = 'hidden';
}

function fecharFiltrosMobile() {
  document.body.classList.remove('filtro-mobile-aberto');
  document.body.style.overflow = '';
}

// Abrindo ao clicar no FAB
$(document).on('click', '#btn-filtros-fab', function(e) {
  e.stopPropagation();
  abrirFiltrosMobile();
});

// Fechando ao clicar no backdrop
$(document).on('click', '#filtro-mobile-backdrop', function() {
  fecharFiltrosMobile();
});

// Fechando ao clicar no botão de fechar dentro do painel
$(document).on('click', '#btn-filtros-fechar', function() {
  fecharFiltrosMobile();
});

// Fechando o painel ao clicar no botão de atualizar (mobile)
$(document).on('click', '#btn_atualizar', function() {
  if (window.innerWidth <= 1199) {
    fecharFiltrosMobile();
  }
});

// Abrindo o painel ao remover um chip de filtro (mobile)
$(document).on('shiny:inputchanged', function(e) {
  if (e.name === 'remover_filtro_id' && window.innerWidth <= 1199) {
    abrirFiltrosMobile();
  }
});

// Restaura overflow e classe ao ampliar a janela além do breakpoint
$(window).on('resize', function() {
  if (window.innerWidth > 1199) {
    document.body.classList.remove('filtro-mobile-aberto');
    document.body.style.overflow = '';
  }
});

// --- Oculta o FAB quando o usuário desce até a seção de botões de blocos ---
// Usa IntersectionObserver no sentinela .div-botoes-blocos para alternar a
// classe .fab-abaixo-blocos no body (apenas em mobile)
(function() {
  function configurarObserverBlocos() {
    var sentinel = document.querySelector('.div-botoes-blocos');
    if (!sentinel || !('IntersectionObserver' in window)) return;

    var observer = new IntersectionObserver(function(entries) {
      if (window.innerWidth > 1199) return;
      entries.forEach(function(entry) {
        if (entry.isIntersecting) {
          // Seção de blocos visível: ocultar o FAB
          document.body.classList.add('fab-abaixo-blocos');
        } else {
          // Saiu da seção de blocos (user rolou para cima ou está acima)
          if (entry.boundingClientRect.top > 0) {
            // Seção ainda não foi atingida (está abaixo da viewport)
            document.body.classList.remove('fab-abaixo-blocos');
          } else {
            // Seção já passou (está acima da viewport): oculta
            document.body.classList.add('fab-abaixo-blocos');
          }
        }
      });
    }, { threshold: 0 });

    observer.observe(sentinel);
  }

  // Configura após o DOM e após mudanças de aba (a seção só existe fora da home)
  $(document).ready(configurarObserverBlocos);
  $(document).on('shiny:inputchanged', function(e) {
    if (e.name === 'abas') {
      setTimeout(configurarObserverBlocos, 200);
    }
  });
})();

// =============================================================================
// 11. ESTADOS DE CARREGAMENTO DOS BOTÕES
//     Desabilita e exibe ícone animado nos botões "Atualizar" e "Acessar a
//     Visão Geral" enquanto a operação está em andamento, restaurando-os ao
//     retornar ao idle para melhor percepção de carregamento pelo usuário.
// =============================================================================

// Helper: coloca um botão no estado de carregamento
function setBtnCarregando($btn, texto, spinnerDireita) {
  var classeSpinnerDireita = spinnerDireita ? ' btn-carregando-spinner-direita' : '';
  $btn.prop('disabled', true).data('original-html', $btn.html()).addClass('btn-carregando' + classeSpinnerDireita);
  if (spinnerDireita) {
    $btn.html(texto + ' <i class="fa fa-spinner fa-spin fa-fw" aria-hidden="true"></i>');
  } else {
    $btn.html('<i class="fa fa-spinner fa-spin fa-fw" aria-hidden="true"></i> ' + texto);
  }
}

// Helper: restaura um botão ao seu estado original
function setBtnPronto($btn) {
  if (!$btn.length) return;
  var html = $btn.data('original-html');
  if (html) $btn.html(html);
  $btn.prop('disabled', false).removeClass('btn-carregando btn-carregando-spinner-direita');
}

// --- Botão "Atualizar" (app_ui.R) --- // //
// O servidor chama shinyjs::enable("btn_atualizar") reativamente durante o
// processamento, o que removeria o atributo disabled antes do idle. Um
// MutationObserver re-desabilita o botão enquanto o loading estiver ativo,
// garantindo que ele permaneça bloqueado até o idle completo.

var _btnAtuAtivo = false;
var _btnAtuBusy = false;
var _btnAtuIgnoreObs = false;
var _btnAtuIdleTimer = null;
var _btnAtuWatchdogTimer = null;
var _btnAtuStartPendente = false;

function tentarIniciarBotaoAtualizarPendente() {
  if (!_btnAtuStartPendente || _btnAtuAtivo) return;
  var $botao = $('#btn_atualizar');
  if (!$botao.length) return;
  iniciarBotaoAtualizar($botao);
}

function iniciarBotaoAtualizar($btn) {
  var $botao = ($btn && $btn.length) ? $btn : $('#btn_atualizar');
  if (_btnAtuAtivo) return;
  if (!$botao.length) {
    _btnAtuStartPendente = true;
    return;
  }

  _btnAtuStartPendente = false;
  _btnAtuAtivo = true;
  _btnAtuBusy = false;
  setBtnCarregando($botao, 'Atualizando...');

  // Contingência para não deixar o botão preso em loading em caso extremo.
  clearTimeout(_btnAtuIdleTimer);
  clearTimeout(_btnAtuWatchdogTimer);
  _btnAtuWatchdogTimer = setTimeout(function() {
    if (_btnAtuAtivo) {
      finalizarBotaoCarregando('btn_atualizar');
    }
  }, 15000);
}

$(document).on('shiny:connected', function() {
  var el = document.getElementById('btn_atualizar');
  if (!el || !window.MutationObserver) return;
  new MutationObserver(function(mutations) {
    if (_btnAtuIgnoreObs) return;
    mutations.forEach(function(m) {
      if (m.attributeName === 'disabled' && _btnAtuAtivo && !el.hasAttribute('disabled')) {
        el.setAttribute('disabled', 'disabled');
      }
    });
  }).observe(el, { attributes: true, attributeFilter: ['disabled'] });
});

$(document).on('click', '#btn_atualizar', function() {
  iniciarBotaoAtualizar($(this));
  // Scroll suave ao topo ao clicar em Atualizar (qualquer página)
  window.scrollTo({ top: 0, behavior: 'smooth' });
});

$(document).on('click', '#btn_ir_para_painel', function() {
  iniciarBotaoAtualizar();
});

// --- Botão "Acessar a Visão Geral" (mod_home.R) --- // //
// O fluxo da home tem um setTimeout de 100ms entre as duas fases de
// processamento server-side, o que pode gerar um idle transitório entre elas.
// Mantemos um debounce curto para evitar restauração prematura sem deixar o
// botão visivelmente atrasado após o carregamento terminar.

var _btnVGAtivo = false;
var _btnVGBusy = false;
var _btnVGTimer = null;

function finalizarBotaoCarregando(botaoId) {
  if (botaoId === 'btn_atualizar') {
    _btnAtuStartPendente = false;
    clearTimeout(_btnAtuIdleTimer);
    _btnAtuIdleTimer = null;
    clearTimeout(_btnAtuWatchdogTimer);
    _btnAtuWatchdogTimer = null;
    _btnAtuAtivo = false;
    _btnAtuBusy = false;
    _btnAtuIgnoreObs = true;
    setBtnPronto($('#btn_atualizar'));
    _btnAtuIgnoreObs = false;
    return;
  }

  if (botaoId === 'home_1-btn_ir_visao_geral') {
    clearTimeout(_btnVGTimer);
    _btnVGAtivo = false;
    _btnVGBusy = false;
    setBtnPronto($('#home_1-btn_ir_visao_geral'));
    return;
  }

  // Fallback genérico: restaura qualquer outro botão pelo seu ID
  var $btnGenerico = $('#' + botaoId);
  if ($btnGenerico.length) {
    setBtnPronto($btnGenerico);
    if (_btnDetAtivo !== null && $btnGenerico.is(_btnDetAtivo)) {
      _btnDetAtivo = null;
    }
  }
}

$(document).on('click', '#home_1-btn_ir_visao_geral', function() {
  _btnVGAtivo = true;
  _btnVGBusy = false;
  setBtnCarregando($(this), 'Carregando página...');
  iniciarBotaoAtualizar();
});

// --- Botão "Explorar série histórica" (mod_indicadores.R) --- // //
// Captura qualquer botão com classe .btn-detalhes-completude (namespaced no
// módulo). O servidor envia 'loading-complete' com o ID completo após showModal().
var _btnDetAtivo = null;

// =============================================================================
// 12. MÓDULO DE INDICADORES — TRANSIÇÃO HORIZONTAL DE GRÁFICOS
//     Substitui o shinyjs::show/hide com slide pela transição coordenada:
//     (1) cross-fade entre painel agrupado e individual via CSS Grid overlay;
//     (2) coluna de linha encolhe de 100% → 50% antes do scatter aparecer;
//     (3) scatter entra com fade + translateX após o resize da linha.
//     Ao voltar: scatter some primeiro, linha cresce, depois cross-fade.
// =============================================================================

(function() {
  // Estado interno (evita conflitos em animações sobrepostas)
  var _pendingTimer = null;
  var _activeLinhaHandler = null;
  var _activeScatterHandler = null;

  // Aguarda o fim da transição de flex-basis na coluna de linha, com fallback
  function aguardarLinhaTransition(colLinha, cb) {
    var resolved = false;

    function resolver() {
      if (resolved) return;
      resolved = true;
      if (_activeLinhaHandler) {
        colLinha.removeEventListener('transitionend', _activeLinhaHandler);
        _activeLinhaHandler = null;
      }
      cb();
    }

    // Fallback: garante execução mesmo que transitionend não dispare (ex: mobile)
    var fallback = setTimeout(resolver, 420);

    _activeLinhaHandler = function(e) {
      if (e.propertyName !== 'flex-basis' && e.propertyName !== 'max-width') return;
      clearTimeout(fallback);
      resolver();
    };

    colLinha.addEventListener('transitionend', _activeLinhaHandler);
  }

  // Aguarda o fim da transição de flex-basis na coluna de scatter, com fallback
  function aguardarScatterTransition(colScatter, cb) {
    var resolved = false;

    function resolver() {
      if (resolved) return;
      resolved = true;
      if (_activeScatterHandler) {
        colScatter.removeEventListener('transitionend', _activeScatterHandler);
        _activeScatterHandler = null;
      }
      cb();
    }

    var fallback = setTimeout(resolver, 420);

    _activeScatterHandler = function(e) {
      if (e.propertyName !== 'flex-basis' && e.propertyName !== 'max-width') return;
      clearTimeout(fallback);
      resolver();
    };

    colScatter.addEventListener('transitionend', _activeScatterHandler);
  }

  // Força reflow dos Highcharts contidos no wrapper e dispara resize global
  function reflowCharts(wrapper) {
    setTimeout(function() {
      if (typeof Highcharts !== 'undefined') {
        Highcharts.charts.forEach(function(chart) {
          if (!chart) return;
          var container = chart.renderTo;
          if (container && wrapper.contains(container)) {
            chart.reflow();
          }
        });
      }
      window.dispatchEvent(new Event('resize'));
    }, 50);
  }

  Shiny.addCustomMessageHandler('switchGraficosModo', function(data) {
    var modo = data.modo;
    var somenteScatter = Boolean(data.somente_scatter);
    var wrapperId = data.wrapper_id;
    var wrapper = document.getElementById(wrapperId);
    if (!wrapper) return;

    var panelInd = wrapper.querySelector('.graficos-panel-individual');
    var colLinha = wrapper.querySelector('.graf-col-linha');
    var colScatter = wrapper.querySelector('.graf-col-scatter');
    var panelAg = wrapper.querySelector('.graficos-panel-agrupado');
    if (!panelInd || !colLinha || !colScatter || !panelAg) return;

    var wasSomenteScatter = wrapper.classList.contains('modo-somente-scatter');

    var isMobile = window.innerWidth < 1200;

    // Guarda de idempotência: não reinicia animação se já no estado final correto.
    // Necessário como segunda linha de defesa além do observeEvent no servidor.
    if (modo === 'individual') {
      var jaIndividual = wrapper.classList.contains('modo-individual');
      if (somenteScatter) {
        if (jaIndividual && wasSomenteScatter && colScatter.classList.contains('scatter-visivel')) return;
      } else {
        if (isMobile && jaIndividual && !wasSomenteScatter) return;
        if (!isMobile && jaIndividual &&
            panelInd.classList.contains('modo-duplo') &&
            colScatter.classList.contains('scatter-visivel')) return;
      }
    } else {
      if (!wrapper.classList.contains('modo-individual')) return;
    }

    // Cancela qualquer animação pendente antes de iniciar nova
    if (_pendingTimer !== null) {
      clearTimeout(_pendingTimer);
      _pendingTimer = null;
    }
    if (_activeLinhaHandler) {
      colLinha.removeEventListener('transitionend', _activeLinhaHandler);
      _activeLinhaHandler = null;
    }
    if (_activeScatterHandler) {
      colScatter.removeEventListener('transitionend', _activeScatterHandler);
      _activeScatterHandler = null;
    }

    wrapper.classList.remove('transicao-saindo-somente-scatter');
    wrapper.classList.remove('transicao-entrada-linha');
    colLinha.classList.remove('linha-saindo');
    colLinha.classList.remove('linha-entrada-visivel');

    // === MOBILE: troca instantânea, sem animação ===
    // Animação no mobile causa layout shift vertical — mantém apenas
    // a lógica de show/hide sincronizada com a classe CSS.
    if (isMobile) {
      if (modo === 'individual') {
        wrapper.classList.add('modo-individual');
        if (somenteScatter) {
          wrapper.classList.add('modo-somente-scatter');
          panelInd.classList.remove('modo-duplo');
          colScatter.classList.add('scatter-visivel');
        } else {
          wrapper.classList.remove('modo-somente-scatter');
        }
      } else {
        wrapper.classList.remove('modo-individual');
        wrapper.classList.remove('modo-somente-scatter');
      }
      // Força reflow dos Highcharts para evitar spinner infinito quando
      // o painel passa de display:none para visível.
      reflowCharts(wrapper);
      return;
    }

    // === DESKTOP: animação completa com cross-fade + resize horizontal ===
    if (modo === 'individual') {
      if (somenteScatter) {
        // Sequência desejada (indicador especial):
        // 1) some o card de linha, 2) scatter expande para 100%.
        wrapper.classList.add('modo-individual');
        colScatter.classList.add('scatter-visivel');

        colLinha.classList.add('linha-saindo');

        _pendingTimer = setTimeout(function() {
          _pendingTimer = null;
          panelInd.classList.remove('modo-duplo');
          wrapper.classList.add('modo-somente-scatter');

          aguardarLinhaTransition(colLinha, function() {
            colLinha.classList.remove('linha-saindo');
            reflowCharts(wrapper);
          });
        }, 220);
        return;
      }

      // Saindo do modo somente-scatter para modo individual com 2 gráficos:
      // 1) scatter encolhe para 50% (ancorado à direita),
      // 2) linha reaparece com animação no espaço liberado.
      if (wasSomenteScatter) {
        wrapper.classList.add('modo-individual');
        colScatter.classList.add('scatter-visivel');
        panelInd.classList.remove('modo-duplo');
        wrapper.classList.add('transicao-saindo-somente-scatter');

        aguardarScatterTransition(colScatter, function() {
          panelInd.classList.add('modo-duplo');
          wrapper.classList.remove('transicao-saindo-somente-scatter');
          wrapper.classList.remove('modo-somente-scatter');
          wrapper.classList.add('transicao-entrada-linha');

          requestAnimationFrame(function() {
            requestAnimationFrame(function() {
              colLinha.classList.add('linha-entrada-visivel');

              _pendingTimer = setTimeout(function() {
                _pendingTimer = null;
                wrapper.classList.remove('transicao-entrada-linha');
                reflowCharts(wrapper);
              }, 320);
            });
          });
        });
        return;
      }

      wrapper.classList.remove('modo-somente-scatter');

      // Garante estado inicial dentro do painel individual
      panelInd.classList.remove('modo-duplo');
      colScatter.classList.remove('scatter-visivel');

      // Passo 1: cross-fade (agrupado → individual, 200ms)
      wrapper.classList.add('modo-individual');

      // Passo 2: após cross-fade, anima linha de 100% → 50%
      _pendingTimer = setTimeout(function() {
        _pendingTimer = null;
        panelInd.classList.add('modo-duplo');

        // Passo 3: após resize da linha, mostra scatter
        aguardarLinhaTransition(colLinha, function() {
          colScatter.classList.add('scatter-visivel');
        });
      }, 220);

    } else {
      wrapper.classList.remove('modo-somente-scatter');

      // Passo 1: scatter some primeiro (300ms pela transição opacity)
      colScatter.classList.remove('scatter-visivel');

      // Passo 2: após scatter desaparecer, linha cresce de 50% → 100%
      _pendingTimer = setTimeout(function() {
        _pendingTimer = null;
        panelInd.classList.remove('modo-duplo');

        // Passo 3: após resize da linha, cross-fade de volta ao agrupado
        aguardarLinhaTransition(colLinha, function() {
          wrapper.classList.remove('modo-individual');
          reflowCharts(wrapper);
        });
      }, 320);
    }
  });
})();

$(document).on('click', '.btn-detalhes-completude', function() {
  _btnDetAtivo = $(this);
  setBtnCarregando(_btnDetAtivo, 'Carregando visualizações...', true);
});

// Ciclo busy/idle: marca quando a app ficou ocupada e cancela timers de debounce
$(document).on('shiny:busy', function() {
  if (_btnAtuAtivo) {
    _btnAtuBusy = true;
    clearTimeout(_btnAtuIdleTimer);
  }

  if (_btnVGAtivo) {
    _btnVGBusy = true;
    clearTimeout(_btnVGTimer);
  }
});

// Ao retornar ao idle, restaura os botões com fallback apenas onde não há
// confirmação explícita do servidor para o fim do carregamento.
$(document).on('shiny:idle', function() {
  if (_btnAtuAtivo) {
    clearTimeout(_btnAtuIdleTimer);
    var idleDebounce = _btnAtuBusy ? 900 : 300;
    _btnAtuIdleTimer = setTimeout(function() {
      finalizarBotaoCarregando('btn_atualizar');
    }, idleDebounce);
  }

  if (_btnVGAtivo && _btnVGBusy) {
    clearTimeout(_btnVGTimer);
    _btnVGTimer = setTimeout(function() {
      finalizarBotaoCarregando('home_1-btn_ir_visao_geral');
    }, 600);
  }

  if (_btnDetAtivo !== null) {
    setBtnPronto(_btnDetAtivo);
    _btnDetAtivo = null;
  }
});

// Gatilhos explícitos enviados pelo servidor quando o flush termina.
Shiny.addCustomMessageHandler('loading-complete', function(message) {
  finalizarBotaoCarregando(message && message.button ? message.button : 'btn_atualizar');
});

// Se o start ocorreu antes do botão existir no DOM (ex.: Home -> Visão Geral),
// tenta iniciar assim que os primeiros outputs começarem a ser entregues.
$(document).on('shiny:value', function() {
  tentarIniciarBotaoAtualizarPendente();
});

// --- Mudança de aba via navbar --- //
// Ao navegar pela navbar (input$navmenu), coloca o botão "Atualizar" no estado
// de carregamento.
$(document).on('shiny:inputchanged', function(event) {
  if (event.name === 'abas') {
    if (event.value === 'visao_geral') {
      iniciarBotaoAtualizar();
      setTimeout(tentarIniciarBotaoAtualizarPendente, 0);
      setTimeout(tentarIniciarBotaoAtualizarPendente, 120);
    } else {
      _btnAtuStartPendente = false;
    }
    return;
  }

  if (event.name !== 'navmenu') return;
  var navValue = String(event.value || '');
  if (!navValue || navValue === 'home') return;

  var isVisaoGeral = navValue === 'visao_geral';
  var isDetalheNavbar = navValue.indexOf('-') !== -1;
  if (!isVisaoGeral && !isDetalheNavbar) return;

  iniciarBotaoAtualizar();
});

// Quando o servidor confirma que a atualização foi processada, mudamos a aba
Shiny.addCustomMessageHandler("home-atualizar-complete", function(message) {
  finalizarBotaoCarregando(message && message.button ? message.button : 'home_1-btn_ir_visao_geral');
  if (_btnAtuAtivo) {
    finalizarBotaoCarregando('btn_atualizar');
  }
  openTab('visao_geral');
  window.scrollTo({top: 0, behavior: 'smooth'});
});

// =============================================================================
// 12. TOOLTIPS GENÉRICAS (data-copilot-tooltip)
//     Exibe uma tooltip posicionada com position: fixed para qualquer elemento
//     que possua o atributo data-copilot-tooltip. Funciona corretamente dentro de
//     containers com overflow: hidden (ex: chips de filtro), pois o elemento
//     de tooltip é anexado ao body. Oculta ao sair do alvo, ao clicar ou ao
//     rolar a página.
// =============================================================================

(function() {
  var SPACING = 8;
  var VIEWPORT_PADDING = 8;
  var tooltipEl = null;
  var currentTarget = null;
  var rafId = null;

  function ensureTooltipEl() {
    if (tooltipEl) return tooltipEl;
    tooltipEl = document.createElement('div');
    tooltipEl.className = 'icon-tooltip-popup';
    tooltipEl.style.display = 'none';
    document.body.appendChild(tooltipEl);
    return tooltipEl;
  }

  function hideGenericTooltip() {
    currentTarget = null;
    if (rafId) { cancelAnimationFrame(rafId); rafId = null; }
    if (!tooltipEl) return;
    tooltipEl.classList.remove('is-visible');
    // Aguarda a transição de saída antes de ocultar com display:none
    setTimeout(function() {
      if (!tooltipEl.classList.contains('is-visible')) {
        tooltipEl.style.display = 'none';
      }
    }, 160);
  }

  function showGenericTooltip(target) {
    var text = target.getAttribute('data-copilot-tooltip');
    if (!text) return;

    // Não exibe em elementos desabilitados (ex.: "X" de chip sem valor)
    if (target.classList.contains('is-disabled')) return;

    // Não exibe em controles nativos desabilitados (ex.: botão "Abrir filtros
    // rápidos" ou "Atualizar" enquanto a cadeia de localização não está completa)
    if (target.matches(':disabled')) return;

    // Não exibe em elementos com classe active (ex: dropdown de filtros aberto)
    if (target.classList.contains('active')) return;

    var el = ensureTooltipEl();
    el.textContent = text;
    el.style.display = 'block';
    el.classList.remove('is-visible', 'position-below');

    void el.offsetHeight; // força reflow para obter dimensões reais

    var tRect = target.getBoundingClientRect();
    var eWidth = el.offsetWidth;
    var eHeight = el.offsetHeight;
    var targetCenterX = tRect.left + tRect.width / 2;

    // Posição preferida: acima do alvo
    var top = tRect.top - eHeight - SPACING;
    var posBelow = false;

    if (top < VIEWPORT_PADDING) {
      top = tRect.bottom + SPACING;
      posBelow = true;
    }

    // Restringe a posição horizontal aos limites da viewport
    var left = targetCenterX - eWidth / 2;
    var clampedLeft = Math.max(VIEWPORT_PADDING, Math.min(left, window.innerWidth - eWidth - VIEWPORT_PADDING));

    // Ajusta a seta para apontar ao centro do alvo mesmo após clamping
    var arrowOffset = targetCenterX - clampedLeft;
    arrowOffset = Math.max(10, Math.min(arrowOffset, eWidth - 10));

    el.style.top = top + 'px';
    el.style.left = clampedLeft + 'px';
    el.style.setProperty('--arrow-offset', arrowOffset + 'px');

    if (posBelow) {
      el.classList.add('position-below');
    }

    currentTarget = target;
    rafId = requestAnimationFrame(function() {
      if (currentTarget !== target) return;
      el.classList.add('is-visible');
    });
  }

  $(document).on('mouseenter', '[data-copilot-tooltip]', function() {
    showGenericTooltip(this);
  });

  $(document).on('mouseleave click', '[data-copilot-tooltip]', function() {
    hideGenericTooltip();
  });

  window.addEventListener('scroll', hideGenericTooltip, true);
})();


// =============================================================================
// 12b. BOTÃO "X" DAS CHIPS DE FILTRO — ESTADO DE HABILITAÇÃO
//      A habilitação do "X" reflete o estado VIVO do input correspondente
//      (não o estado visual da chip, que só muda no "Atualizar"). O servidor é
//      a fonte de verdade: envia estado_remover_chips a cada mudança de input;
//      aqui apenas aplicamos/removemos a classe 'is-disabled' no botão.
//      A classe desabilitada: cursor not-allowed, sem hover, sem tooltip e sem
//      clique (removerFiltroChip ignora o clique).
// =============================================================================
(function() {
  var estadoUltimo = {};

  // Aplica o último estado recebido do servidor a todos os botões presentes.
  // Pode rodar após re-render das chips (MutationObserver) — os novos nós
  // herdam o estado correspondente ao estado atual dos inputs.
  function aplicarEstadoXs() {
    document.querySelectorAll('.filter-chip-remove').forEach(function(el) {
      var id = el.getAttribute('data-remover-input');
      if (id && Object.prototype.hasOwnProperty.call(estadoUltimo, id)) {
        el.classList.toggle('is-disabled', !estadoUltimo[id]);
      }
    });
  }

  Shiny.addCustomMessageHandler('estado_remover_chips', function(estado) {
    estadoUltimo = estado || {};
    aplicarEstadoXs();
  });

  // Clique no "X": apenas quando habilitado (e o servidor ainda confere).
  window.removerFiltroChip = function(el) {
    var id = el.getAttribute('data-remover-input');
    if (!id || el.classList.contains('is-disabled')) return;
    Shiny.setInputValue('remover_filtro_id', id, {priority: 'event'});
  };

  // Chips são renderUI (HTML bruto, sem binding Shiny): um MutationObserver
  // reaplica o estado sempre que o container é re-renderizado — cobre o
  // recálculo por navbar/Atualizar quando inputs e estado congelado divergem.
  document.querySelectorAll('.filtros-ativos-chips-output').forEach(function(container) {
    new MutationObserver(aplicarEstadoXs).observe(container, {
      childList: true,
      subtree: true
    });
  });

  // Garantia extra para o primeiro render (mensagem pode chegar antes do HTML).
  $(document).on('shiny:connected', aplicarEstadoXs);
})();


// =============================================================================
// 13. VALUEBOXES — REPOSICIONAMENTO DE TOOLTIPS (.vb-tooltip-conteudo)
//     Ao passar o mouse sobre .vb-info-btn, verifica se a tooltip filha
//     (.vb-tooltip-conteudo) ultrapassa os limites horizontais da viewport.
//     Quando detecta overflow, adiciona a classe .vb-tooltip-clamped-right ou
//     .vb-tooltip-clamped-left, que sobrescrevem o posicionamento padrão via
//     CSS. Remove as classes ao sair do hover.
//     Além do hover, o clamp roda de forma PROATIVA (load, resize e após cada
//     re-render dos outputs): a tooltip escondida usa `visibility: hidden`,
//     que a mantém no layout — ou seja, ela conta para o scroll horizontal da
//     página mesmo invisível. Sem o clamp proativo, uma tooltip centralizada
//     perto da borda direita força a barra de rolagem lateral desde o
//     carregamento das visualizações, antes de qualquer hover.
// =============================================================================
(function() {
  var PADDING = 8;

  function clampTooltip(btn) {
    var tip = btn.querySelector('.vb-tooltip-conteudo');
    if (!tip) return;

    // Desativa transição para medir e reposicionar sem animação
    tip.style.transition = 'none';

    // Remove ajustes anteriores para medir a posição natural
    tip.classList.remove('vb-tooltip-clamped-right', 'vb-tooltip-clamped-left');

    // Força exibição temporária para medir
    tip.style.opacity = '0';
    tip.style.visibility = 'hidden';
    tip.style.display = 'block';
    void tip.offsetHeight;

    var rect = tip.getBoundingClientRect();
    var vw = window.innerWidth;

    // Ignora tooltips sem layout (abas ocultas, outputs ainda não
    // renderizados): o rect zerado seria clampado incorretamente à esquerda.
    // Esses casos caem no clamp do mouseenter quando ficarem visíveis.
    if (rect.width === 0 && rect.height === 0) {
      tip.style.transition = '';
      tip.style.opacity = '';
      tip.style.visibility = '';
      tip.style.display = '';
      return;
    }

    // Aplica a classe de clamping (sem transição — posição é instantânea)
    if (rect.right > vw - PADDING) {
      tip.classList.add('vb-tooltip-clamped-right');
    } else if (rect.left < PADDING) {
      tip.classList.add('vb-tooltip-clamped-left');
    }

    // Força reflow com a nova posição já aplicada
    void tip.offsetHeight;

    // Re-habilita transição e limpa overrides — o CSS :hover cuidará da
    // animação suave de opacidade e deslize vertical a partir daqui
    tip.style.transition = '';
    tip.style.opacity = '';
    tip.style.visibility = '';
    tip.style.display = '';
  }

  function clampAllTooltips() {
    var btns = document.querySelectorAll('.vb-info-btn');
    for (var i = 0; i < btns.length; i++) {
      clampTooltip(btns[i]);
    }
  }

  // Não remove a classe no mouseleave — ela persiste durante a animação de
  // saída para evitar o salto visual ao centro. A classe é removida somente
  // no próximo mouseenter, antes da nova medição.
  $(document).on('mouseenter', '.vb-info-btn', function() {
    clampTooltip(this);
  });

  // Clamp proativo com debounce: os valueBoxes re-renderizam a cada
  // "Atualizar" (e as abas trocam o layout), então uma única passada no load
  // não basta. O debounce agrega rajadas de mutações num único passe.
  function agendarClampProativo() {
    if (agendarClampProativo._t) return;
    agendarClampProativo._t = setTimeout(function() {
      agendarClampProativo._t = null;
      clampAllTooltips();
    }, 150);
  }

  // Re-renders do Shiny (valueBoxes) e redimensionamento da janela.
  $(document).on('shiny:connected shiny:value', function() {
    agendarClampProativo();
  });
  $(window).on('resize', function() {
    agendarClampProativo();
  });

  // Mudanças no DOM (troca de aba, outputs recriados) disparam o reclamp.
  // O observer só pode ser anexado com o <body> já existente (este script é
  // incluído no <head> via bundle_resources): tenta no ready com fallback na
  // conexão do Shiny.
  function iniciarObserverTooltips() {
    if (iniciarObserverTooltips._on || !window.MutationObserver || !document.body) return;
    iniciarObserverTooltips._on = true;
    var obsTooltips = new MutationObserver(function() {
      agendarClampProativo();
    });
    obsTooltips.observe(document.body, { childList: true, subtree: true });
  }
  $(document).ready(function() {
    iniciarObserverTooltips();
  });
  $(document).on('shiny:connected', function() {
    iniciarObserverTooltips();
  });

  // Primeira passada após o parse (cobre o HTML estático antes do Shiny).
  agendarClampProativo();
})();


// =============================================================================
// SLIM SELECT — BUSCA IGNORANDO ACENTUAÇÃO
//   Sobrescreve o searchFilter padrão do Slim Select (que faz indexOf simples
//   em lowercase) por uma versão que normaliza texto e busca com
//   String.prototype.normalize('NFD') + remoção de diacríticos. O valor
//   exibido ao usuário permanece inalterado; apenas a comparação é afetada.
//   Aplica-se globalmente a todos os slimSelectInput()/updateSlimSelect().
// =============================================================================
(function() {
  function normalizeText(str) {
    return (str || '')
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase();
  }

  function accentInsensitiveSearchFilter(option, search) {
    return normalizeText(option.text).indexOf(normalizeText(search)) !== -1;
  }

  function patchSlimSelectInstance(instance) {
    if (!instance || !instance.events) return;
    instance.events.searchFilter = accentInsensitiveSearchFilter;
  }

  // Fecha o dropdown de selects com contentLocation logo após o init: o
  // binding do shinyWidgets 0.9.1 abre (s.open()) todo select com
  // contentLocation na inicialização (slim-select 2.8.2) — sem isso, os
  // dropdowns da Home (e quaisquer outros com contentLocation visíveis no
  // load, ex.: filtros rápidos) nascem abertos sobre a página. Roda DEPOIS do
  // open do init (preserva eventuais efeitos colaterais dele) e SÓ no init:
  // nunca em interação do usuário nem em updates do servidor.
  // TRUE se a instância usa contentLocation (dropdown fora do <body>).
  // Pós-init, a lib REMOVE o <script data-for> do DOM, então a detecção
  // confiável é via instance.settings (onde contentLocation vira o ELEMENTO
  // do wrapper). O JSON do <script> só existe pré-init (fallback).
  function slimTemContentLocation(el, instance) {
    if (instance && instance.settings && instance.settings.contentLocation) {
      return true;
    }
    var cfgEl = el && el.querySelector ?
      el.querySelector('script[data-for="' + el.id + '"]') : null;
    if (!cfgEl) return false;
    try {
      var settings = (JSON.parse(cfgEl.text) || {}).settings || null;
      return !!(settings && settings.contentLocation);
    } catch (e) {
      return false;
    }
  }

  function fecharSlimSelectInit(el, instance, origem) {
    if (!el || !instance || typeof instance.close !== 'function') return;
    if (!slimTemContentLocation(el, instance)) return;
    try { el.dataset.phCloseAplicado = origem || 'init'; } catch (e) {}
    instance.close();
    // O s.open() do init foca a busca do dropdown — o último inicializado
    // (o hospital único) ficava com o anel de foco no load. Devolve o foco
    // SOMENTE se ele estiver dentro deste select (wrapper com main + busca):
    // nunca rouba foco legítimo do usuário.
    try {
      var wrap = instance.settings && instance.settings.contentLocation;
      var escopo = (wrap && wrap.nodeType === 1) ? wrap : el;
      var ativo = document.activeElement;
      if (ativo && escopo.contains(ativo)) ativo.blur();
    } catch (e2) {}
  }

  // 1) Intercepta o registro do binding do slim-select para que cada nova
  //    instância seja patchada imediatamente após a inicialização.
  if (window.Shiny && Shiny.inputBindings && Shiny.inputBindings.register) {
    var _origRegister = Shiny.inputBindings.register;
    Shiny.inputBindings.register = function(binding, name) {
      _origRegister.call(this, binding, name);
      if (name !== 'shinyWidgets.slimSelectBinding') return;
      if (binding.__accentInsensitivePatched) return;
      binding.__accentInsensitivePatched = true;

      var origInit = binding.initialize;
      binding.initialize = function(el) {
        origInit.call(this, el);
        // Via closure (não `this`): o contexto de chamada do initialize não
        // é garantido pelo Shiny em todos os caminhos de bind.
        var st = binding.store;
        if (st && st[el.id]) {
          patchSlimSelectInstance(st[el.id]);
          fecharSlimSelectInit(el, st[el.id], 'init');
        }
      };
    };
  }

  // Libera os dropdowns da Home após a inicialização (ver gate
  // `html:not(.ph-slim-liberado)` no custom.css). O delay cobre o fade de
  // saída do fechamento (~200ms): liberar junto revelaria 1-2 frames dos
  // menus ainda fechando.
  function liberarSlimHome() {
    document.documentElement.classList.add('ph-slim-liberado');
  }

  function fecharSlimsAbertos() {
    if (!window.Shiny || !Shiny.inputBindings || !Shiny.inputBindings.bindings) return;
    Shiny.inputBindings.bindings.forEach(function(entry) {
      var b = entry && entry.binding;
      if (!b || b.name !== 'shinyWidgets.slimSelectBinding') return;
      if (!b.store) return;
      for (var id in b.store) {
        if (b.store.hasOwnProperty(id) && b.store[id]) {
          patchSlimSelectInstance(b.store[id]);
          fecharSlimSelectInit(document.getElementById(id), b.store[id], 'sweep');
        }
      }
    });
  }

  // 2) Fallback: cobre instâncias que tenham sido inicializadas antes do hook
  //    acima ser instalado (e.g. em conexões/reativações de sessão).
  $(document).on('shiny:sessioninitialized', function() {
    fecharSlimsAbertos();
    setTimeout(liberarSlimHome, 350);
  });

  // Backstop: interação antes da liberação (Shiny ainda conectando) — fecha
  // tudo e libera após o fade, para o clique nunca revelar um dropdown
  // aberto pelo init (o clique abre o alvo DEPOIS, já liberado).
  document.addEventListener('pointerdown', function() {
    if (document.documentElement.classList.contains('ph-slim-liberado')) return;
    fecharSlimsAbertos();
    setTimeout(liberarSlimHome, 350);
  }, true);

  // Último recurso: se o Shiny nunca inicializar, não prende os dropdowns
  // invisíveis para sempre (nesse estado o app já está quebrado mesmo).
  setTimeout(liberarSlimHome, 15000);
})();

// =============================================================================
// 15. HOME — TRANSIÇÃO COORDENADA DOS INPUTS
//     Orquestra a mudança de grid-template-columns com a entrada/saída dos
//     inputs em 3 fases, evitando quebra de linha no card da home:
//       1) Esconde inputs que devem sair (fade-out CSS de 300ms)
//       2) Após saída, força o fim da saída + deriva o grid do DOM real +
//          mostra os novos inputs — tudo no mesmo frame (atômico)
//       3) Entrada com fade-in via @starting-style
//     Token de geração: trocas rápidas de nível (ou troca durante a carga)
//     gerariam timeouts sobrepostos que se intercalam e travam wrappers no
//     estado errado. Cada chamada invalida as anteriores; o R sempre envia
//     conjuntos ABSOLUTOS de esconder/mostrar, então descartar a transição
//     obsoleta nunca perde estado.
//     Grid por contagem (não pela mensagem): o swap de uma transição
//     descartada nunca roda, então herdar a classe enviada deixaria o grid
//     defasado de uma transição atrás (ocupantes novos em grid velho → quebra
//     de linha). Contando os wrappers que estarão visíveis, o grid sempre casa
//     com a realidade no instante do swap — auto-cura qualquer dessincronia.
// =============================================================================
window.transicionarHomeInputs = (function() {
  var geracao = 0;

  return function(containerId, novaClasse, esconder, mostrar) {
  var minhaGeracao = ++geracao;

  var container = document.getElementById(containerId);
  if (!container) {
    // DOM ainda não pronto (carga inicial lenta): uma nova tentativa em vez
    // do retorno silencioso — desde que nenhuma transição mais nova exista.
    setTimeout(function() {
      if (minhaGeracao !== geracao) return;
      var el = document.getElementById(containerId);
      if (el) window.transicionarHomeInputs(containerId, novaClasse, esconder, mostrar);
    }, 500);
    return;
  }

  var classesGrid = [
    'home-filter-inputs--cols-2',
    'home-filter-inputs--cols-3',
    'home-filter-inputs--cols-4',
    'home-filter-inputs--cols-5'
  ];

  var temSaida = false;
  (esconder || []).forEach(function(id) {
    var el = document.getElementById(id);
    if (el) {
      el.classList.add('home-input-hidden');
      temSaida = true;
    }
  });

  var delayGrid = temSaida ? 300 : 0;

  setTimeout(function() {
    // Transição obsoleta: outra troca de nível a superou — não toca em nada
    // (a transição vencedora carrega os conjuntos completos e atualizados).
    if (minhaGeracao !== geracao) return;

    // Garante o fim da saída ANTES de trocar o grid e exibir os entrantes.
    // ATENÇÃO: aqui NÃO basta `el.style.display = 'none'`, pois o elemento tem
    // `transition: display allow-discrete` — essa atribuição apenas agenda outra
    // virada atrasada (comprovado em teste forense: inline=none com computed
    // ainda block). A classe `home-input-hidden-now` desliga a transição
    // (`transition: none`) no mesmo recalc, então o flip é instantâneo e a fase
    // fica atômica: tudo abaixo cai no mesmo recalc de estilo → um único paint
    // limpo. Forçar aqui é invisível ao usuário (o fade já teve seus 300ms).
    (esconder || []).forEach(function(id) {
      var fora = document.getElementById(id);
      if (fora) { fora.classList.add('home-input-hidden-now'); }
    });

    // Deriva as colunas dos wrappers que ESTARÃO visíveis
    // (visíveis agora − sainte + entrantes), lendo o DOM em vez de confiar na
    // mensagem: nível/UF/período nunca entram nos conjuntos (sempre visíveis)
    // e passam pela contagem natural abaixo. Um wrapper conta como oculto se
    // tem QUALQUER das duas classes de hide (a animada ou a forçada).
    var prefixo = containerId.replace(/home_filter_inputs$/, '');
    var seraVisivel = {};
    var estaOculto = function(filho) {
      return filho.classList.contains('home-input-hidden') ||
        filho.classList.contains('home-input-hidden-now') ||
        filho.style.display === 'none';
    };
    Array.prototype.forEach.call(container.children, function(filho) {
      if (!filho.id || filho.id.indexOf(prefixo + 'home_conditional_') !== 0) return;
      if (!estaOculto(filho) && (esconder || []).indexOf(filho.id) === -1) { seraVisivel[filho.id] = true; }
    });
    (mostrar || []).forEach(function(id) { seraVisivel[id] = true; });
    var classeContada = 'home-filter-inputs--cols-' + Object.keys(seraVisivel).length;
    if (classesGrid.indexOf(classeContada) === -1) {
      classeContada = novaClasse; // fora do range conhecido: usa a enviada pelo R
    }
    classesGrid.forEach(function(cls) {
      container.classList.remove(cls);
    });
    container.classList.add(classeContada);

    requestAnimationFrame(function() {
      if (minhaGeracao !== geracao) return;
      (mostrar || []).forEach(function(id) {
        var el = document.getElementById(id);
        if (el) {
          // Remove AMBAS as classes de hide (a animada e a forçada): seguro
          // porque o R sempre envia conjuntos ABSOLUTOS — todo wrapper visível
          // no nível destino passa por este loop, então nenhum hide sobrevive.
          el.classList.remove('home-input-hidden-now');
          el.classList.remove('home-input-hidden');
        }
      });
    });
  }, delayGrid);
  };
})();
