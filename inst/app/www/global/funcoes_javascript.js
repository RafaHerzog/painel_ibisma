/* =============================================================================
   FUNÇÕES JAVASCRIPT DO PAINEL IBISMA
   Reúne o handler que atualiza as cores do mapa sem reenviar a geometria e a
   marcação da seção visível na barra de navegação.
   ============================================================================= */

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

/* Inicializando as tooltips das pétalas do perfil municipal */
(function () {
  /* Executando a função imediatamente quando a página já estiver pronta */
  function quandoPronto(fn) {
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", fn);
    } else {
      fn();
    }
  }

  /* Ativando o tooltip do Bootstrap nas pétalas que ainda não o receberam */
  function inicializarTooltipsPetalas() {
    if (!window.bootstrap || !bootstrap.Tooltip) return;
    var petalas = document.querySelectorAll(
      '.grupo-petala[data-bs-toggle="tooltip"]'
    );
    petalas.forEach(function (el) {
      if (el.dataset.tooltipIniciado) return;
      el.dataset.tooltipIniciado = "sim";
      new bootstrap.Tooltip(el, {
        html: true,
        placement: "top",
        customClass: "tooltip-ibisma",
        container: "body",
        delay: { show: 80, hide: 40 }
      });
    });
  }

  quandoPronto(function () {
    inicializarTooltipsPetalas();

    /* Reinicializando sempre que o Shiny inserir novas pétalas na página */
    var observador = new MutationObserver(function (mutacoes) {
      for (var i = 0; i < mutacoes.length; i++) {
        var adicionados = mutacoes[i].addedNodes;
        for (var j = 0; j < adicionados.length; j++) {
          var no = adicionados[j];
          if (no.nodeType !== 1) continue;
          var temPetala =
            (no.matches && no.matches(".grupo-petala")) ||
            (no.querySelector && no.querySelector(".grupo-petala"));
          if (temPetala) {
            inicializarTooltipsPetalas();
            return;
          }
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
