/* =============================================================================
   FUNÇÕES JAVASCRIPT DO PAINEL IBISMA
   Reúne o handler que atualiza as cores do mapa sem reenviar a geometria, a
   abertura animada das duas colunas de comparação e a marcação da seção visível
   na barra de navegação.
   ============================================================================= */

/* Abrindo e fechando as duas colunas quando a comparação é ligada ou desligada */
Shiny.addCustomMessageHandler("ibisma_comparacao", function (mensagem) {
  /* Aplicando a classe que o CSS usa para animar palcos e gráficos */
  [mensagem.palcos, mensagem.evolucoes].forEach(function (id) {
    var el = document.getElementById(id);
    if (!el) return;
    el.classList.toggle("dupla--comparando", !!mensagem.ativa);
  });

  /* Redimensionando os gráficos depois que a transição de layout terminar */
  [80, 500].forEach(function (atraso) {
    setTimeout(function () {
      window.dispatchEvent(new Event("resize"));
    }, atraso);
  });
});

/* Atualizando cores e tooltips dos municípios já desenhados no mapa */
Shiny.addCustomMessageHandler("ibisma_mapa_atualiza", function (mensagem) {
  /* Localizando o widget leaflet a partir do seletor do mapa */
  var widget = window.HTMLWidgets && HTMLWidgets.find("#" + mensagem.id);
  if (!widget || typeof widget.getMap !== "function") return;
  var mapa = widget.getMap();
  if (!mapa || !mapa.layerManager || !mapa.layerManager._byLayerId) return;

  /* Percorrendo as camadas registradas, que guardam o ID após o caractere \n */
  var camadas = mapa.layerManager._byLayerId;
  Object.keys(camadas).forEach(function (chave) {
    var camada = camadas[chave];
    if (!camada || typeof camada.setStyle !== "function") return;
    var id = chave.indexOf("\n") >= 0 ? chave.split("\n").pop() : String(chave);
    var cor = mensagem.cores ? mensagem.cores[id] : null;
    if (!cor) return;

    camada.setStyle({ fillColor: cor, fillOpacity: 0.88 });

    var rotulo = mensagem.labels ? mensagem.labels[id] : null;
    if (rotulo !== null && rotulo !== undefined && camada.setTooltipContent) {
      camada.setTooltipContent(rotulo);
    }
  });
});

/* =============================================================================
   ESQUELETOS DE CARREGAMENTO
   Mantém os esqueletos apenas no carregamento inicial da página; depois da
   primeira fila de recálculos concluída, eles deixam de aparecer.
   ============================================================================= */
(function () {
  /* Marcando a página como carregada quando o servidor fica ocioso */
  function concluir() {
    /* Esperando eventuais recálculos atrasados do próprio carregamento */
    if (document.querySelectorAll(".recalculating").length) {
      setTimeout(concluir, 250);
      return;
    }
    document.documentElement.classList.add("pagina-carregada");
  }

  /* O primeiro idle acontece quando o carregamento inicial termina */
  if (window.jQuery) {
    jQuery(document).one("shiny:idle", function () {
      setTimeout(concluir, 700);
    });
  }
})();

/* Inicializando as tooltips das pétalas e dos campos territoriais cortados */
(function () {
  /* Reunindo pétalas e campos que revelam o próprio texto no hover */
  var SELETOR_PETALAS = '.grupo-petala[data-bs-toggle="tooltip"]';
  var SELETOR_METRICAS = '.metrica-tooltip[data-tooltip-texto]';

  /* Executando a função imediatamente quando a página já estiver pronta */
  function quandoPronto(fn) {
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", fn);
    } else {
      fn();
    }
  }

  /* Ativando o tooltip do Bootstrap no elemento quando ainda não houver um */
  function criarTooltip(el, rico) {
    if (!window.bootstrap || !bootstrap.Tooltip) return;
    if (bootstrap.Tooltip.getInstance(el)) return;
    var opcoes = {
      placement: "top",
      customClass: "tooltip-ibisma",
      container: "body",
      delay: { show: 80, hide: 40 }
    };
    if (rico) {
      /* As pétalas usam HTML com cores gerado pelo servidor */
      opcoes.html = true;
      /* A sanitização removeria os estilos em linha com as cores da dimensão */
      opcoes.sanitize = false;
    } else {
      /* Os campos territoriais usam o texto completo guardado em data */
      opcoes.title = el.getAttribute("data-tooltip-texto");
    }
    new bootstrap.Tooltip(el, opcoes);
  }

  /* Ativando as tooltips das pétalas, que nunca são cortadas */
  function inicializarPetalas() {
    document.querySelectorAll(SELETOR_PETALAS).forEach(function (el) {
      if (el.dataset.tooltipIniciado) return;
      el.dataset.tooltipIniciado = "sim";
      criarTooltip(el, true);
    });
  }

  /* Ativando a tooltip dos campos territoriais somente quando há corte */
  function atualizarMetricas() {
    if (!window.bootstrap || !bootstrap.Tooltip) return;
    document.querySelectorAll(SELETOR_METRICAS).forEach(function (el) {
      var cortado = el.scrollWidth > el.clientWidth;
      var instancia = bootstrap.Tooltip.getInstance(el);
      if (cortado && !instancia) {
        el.setAttribute("tabindex", "0");
        criarTooltip(el, false);
      } else if (!cortado && instancia) {
        instancia.dispose();
        el.removeAttribute("tabindex");
      }
    });
  }

  /* Reavaliando os cortes depois de a janela mudar de tamanho */
  var reagendado = false;
  function agendarAtualizacao() {
    if (reagendado) return;
    reagendado = true;
    window.requestAnimationFrame(function () {
      reagendado = false;
      atualizarMetricas();
    });
  }

  quandoPronto(function () {
    inicializarPetalas();
    atualizarMetricas();
    window.addEventListener("resize", agendarAtualizacao);

    /* Reavaliando depois que a fonte institucional terminar de carregar */
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(function () {
        atualizarMetricas();
      });
    }

    /* Reinicializando sempre que o Shiny inserir novos elementos na página */
    var observador = new MutationObserver(function (mutacoes) {
      for (var i = 0; i < mutacoes.length; i++) {
        var adicionados = mutacoes[i].addedNodes;
        for (var j = 0; j < adicionados.length; j++) {
          var no = adicionados[j];
          if (no.nodeType !== 1) continue;
          var temPetala =
            (no.matches && no.matches(SELETOR_PETALAS)) ||
            (no.querySelector && no.querySelector(SELETOR_PETALAS));
          var temMetrica =
            (no.matches && no.matches(SELETOR_METRICAS)) ||
            (no.querySelector && no.querySelector(SELETOR_METRICAS));
          if (temPetala) inicializarPetalas();
          if (temMetrica) atualizarMetricas();
          if (temPetala || temMetrica) return;
        }
      }
    });
    observador.observe(document.body, { childList: true, subtree: true });
  });
})();

/* Reposicionando o dropdown do slim select quando ele sai da tela */
(function () {
  /* Movendo o dropdown para a esquerda o suficiente para caber na janela */
  function ajustarDropdown(el) {
    var margem = 8;
    var retangulo = el.getBoundingClientRect();
    var excesso = retangulo.right - (window.innerWidth - margem);
    if (excesso > 0) {
      var esquerda = parseFloat(el.style.left || "0") - excesso;
      el.style.left = Math.max(margem, esquerda) + "px";
    }
  }

  document.addEventListener("DOMContentLoaded", function () {
    /* Observando a classe de abertura que o plugin adiciona ao dropdown */
    var observador = new MutationObserver(function (mutacoes) {
      mutacoes.forEach(function (mutacao) {
        var el = mutacao.target;
        if (!(el instanceof Element)) return;
        if (!el.classList.contains("ss-content")) return;
        var aberto =
          el.classList.contains("ss-open-below") ||
          el.classList.contains("ss-open-above");
        if (aberto) ajustarDropdown(el);
      });
    });
    observador.observe(document.body, {
      attributes: true,
      attributeFilter: ["class"],
      subtree: true
    });
  });
})();

/* Posicionando as seções exatamente abaixo da navbar ao clicar nas âncoras */
(function () {
  var navbar = document.querySelector(".navbar-ibisma");
  if (!navbar) return;

  /* Gravando a altura real da navbar para o CSS compensar o scroll */
  function medirNavbar() {
    var altura = Math.round(navbar.getBoundingClientRect().height);
    document.documentElement.style.setProperty("--altura-navbar", altura + "px");
  }

  /* Respeitando quem prefere menos movimento na rolagem */
  function comportamento() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
      ? "auto"
      : "smooth";
  }

  /* Rolando até a seção descontando a altura viva da navbar */
  function rolarAte(secao) {
    var altura = navbar.getBoundingClientRect().height;
    var topo = secao.getBoundingClientRect().top + window.pageYOffset - altura;
    window.scrollTo({ top: Math.max(topo, 0), behavior: comportamento() });
  }

  /* Medindo agora e acompanhando qualquer mudança de tamanho da barra */
  medirNavbar();
  if (window.ResizeObserver) {
    new ResizeObserver(medirNavbar).observe(navbar);
  }
  window.addEventListener("resize", medirNavbar);

  /* Corrigindo a posição quando a página abre já com uma âncora na URL */
  window.addEventListener("load", function () {
    medirNavbar();
    var secao = location.hash && document.querySelector(location.hash);
    if (secao) {
      var altura = navbar.getBoundingClientRect().height;
      var topo = secao.getBoundingClientRect().top + window.pageYOffset - altura;
      window.scrollTo({ top: Math.max(topo, 0), behavior: "auto" });
    }
  });

  /* Interceptando os cliques para fechar o menu antes de calcular a posição */
  document.querySelectorAll('.navbar-ibisma a[href^="#"]').forEach(function (link) {
    link.addEventListener("click", function (evento) {
      var destino = link.getAttribute("href");
      var secao = destino && document.querySelector(destino);
      if (!secao) return;
      evento.preventDefault();
      var menu = document.getElementById("menu-ibisma");
      var menuAberto = menu && menu.classList.contains("show");
      var concluir = function () {
        medirNavbar();
        rolarAte(secao);
        if (window.history && history.pushState) {
          history.pushState(null, "", destino);
        }
      };
      if (menuAberto) {
        /* Aguardando a animação do menu para medir a altura já recolhida */
        bootstrap.Collapse.getOrCreateInstance(menu).hide();
        setTimeout(concluir, 380);
      } else {
        concluir();
      }
    });
  });
})();

/* Marcando na navbar a seção atualmente visível na página */
(function () {
  var links = [];
  var secoes = [];

  /* Reunindo os pares link/âncora existentes na página */
  function coletar() {
    links = Array.prototype.slice.call(
      document.querySelectorAll(".navbar-ibisma .nav-link")
    );
    secoes = [];
    links.forEach(function (link) {
      var destino = link.getAttribute("href");
      if (!destino || destino.charAt(0) !== "#") return;
      var secao = document.querySelector(destino);
      if (secao) secoes.push({ link: link, secao: secao });
    });
  }

  /* Descobrindo qual seção já entrou na área visível pelo alto da janela */
  function atualizar() {
    if (!secoes.length) return;
    var ativa = null;
    secoes.forEach(function (item) {
      var topo = item.secao.getBoundingClientRect().top;
      if (topo <= 200) ativa = item;
    });
    links.forEach(function (link) {
      link.classList.remove("active");
      link.removeAttribute("aria-current");
    });
    if (ativa) {
      ativa.link.classList.add("active");
      ativa.link.setAttribute("aria-current", "true");
    }
  }

  /* Agendando uma única atualização por quadro de animação */
  var agendado = false;
  function agendar() {
    if (agendado) return;
    agendado = true;
    window.requestAnimationFrame(function () {
      agendado = false;
      atualizar();
    });
  }

  document.addEventListener("DOMContentLoaded", function () {
    coletar();
    atualizar();
    window.addEventListener("scroll", agendar, { passive: true });
    window.addEventListener("resize", agendar);

    /* Fechando o menu móvel ao escolher uma seção */
    document.querySelectorAll("#menu-ibisma .nav-link").forEach(function (link) {
      link.addEventListener("click", function () {
        var menu = document.getElementById("menu-ibisma");
        if (menu && menu.classList.contains("show")) {
          var colapso = bootstrap.Collapse.getInstance(menu);
          if (colapso) colapso.hide();
        }
      });
    });
  });
})();
