/*
   Tarea 3 - Servidor REST en Prolog
   Materia: Inteligencia Artificial / Sistemas Expertos
   FCI - UNACAR

   Integrantes:
     - Alan Daniel Matuz Enriquez  (201482)
     - Gerardo Gomez Perez
   Carrera: Ingenieria en Sistemas Computacionales
   Fecha: 31/10/2026

   Para correr:
     swipl -s servidor.pl -g "iniciar_servidor(8080), mantener_servidor."
   Para detener:
     detener_servidor. halt.

   Endpoints que hicimos:
     1. POST /api/asignar/academia
     2. POST /api/asignar/cuerpo-academico
     3. POST /api/asignar/proyecto
     4. GET  /api/curso/mejor-profesor?id=...
     5. POST /api/asignar/capacitacion
     6. GET  /api/profesor/asignaciones?id=...
*/

:- encoding(utf8).

% librerias necesarias para el servidor y json
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(json)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_cors)).
:- use_module(library(lists)).

% esto es para que funcione desde postman sin problemas de cors
:- set_setting(http:cors, [*]).

% predicados dinamicos para guardar asignaciones en memoria mientras corre el servidor
:- dynamic asignacion_academia/2.
:- dynamic asignacion_ca/2.
:- dynamic asignacion_proyecto/2.
:- dynamic asignacion_curso/2.
:- dynamic asignacion_capacitacion/2.
:- dynamic proyecto/8.        % necesita ser dinamico para poder agregar integrantes
:- dynamic servidor_activo/1.

% --- BASE DE CONOCIMIENTO ---
% los datos de profesores, academias, proyectos, etc.

% profesor(Id, Nombre, Grado, Especialidad, CursosDominados)
% los cursos estan ordenados del que mas domina al que menos
profesor(e1001, "Dra. María Elena Cruz Pérez",      doctorado,    inteligencia_artificial, [c_ia, c_sistexp, c_aprendizaje, c_prolog]).
profesor(e1002, "Mtro. José Luis Hernández Ruiz",    maestria,     bases_datos,             [c_bd1, c_bd2, c_progvis, c_ingsoft]).
profesor(e1003, "Dra. Ana Karen Méndez Ortiz",      doctorado,    ingenieria_software,     [c_ingsoft, c_ads, c_progvis, c_web]).
profesor(e1004, "Mtro. Carlos Alberto Ramírez Sosa", maestria,     redes,                   [c_redes1, c_redes2, c_seguridad]).
profesor(e1005, "Lic. Laura Patricia Gómez Ek",     licenciatura, desarrollo_web,          [c_web, c_movil, c_progvis]).
profesor(e1006, "Dr. Roberto Chablé May",          doctorado,    matematicas,             [c_metnum, c_calculo, c_ia]).
profesor(e1007, "Mtra. Diana Isabel Pech Canul",     maestria,     ciberseguridad,          [c_seguridad, c_redes1, c_bd1]).
profesor(e1008, "Mtro. Fernando Uc Balam",           maestria,     inteligencia_artificial, [c_prolog, c_aprendizaje, c_metnum]).

% cuerpo_academico(Id, Nombre, LineaInvestigacion, Lider, Estatus)
cuerpo_academico(ca_sic, "Sistemas Inteligentes y Cómputo",
                 inteligencia_artificial, e1001, en_consolidacion).
cuerpo_academico(ca_isd, "Ingeniería de Software y Gestión de Datos",
                 ingenieria_software, e1003, en_formacion).
cuerpo_academico(ca_rsc, "Redes y Ciberseguridad Computacional",
                 redes, e1004, en_formacion).

% academia(Id, Nombre, Materias, Lider).
academia(aca_ia,    "Academia de Inteligencia Artificial", [c_ia, c_sistexp, c_aprendizaje, c_prolog],   e1001).
academia(aca_bd,    "Academia de Bases de Datos",          [c_bd1, c_bd2],                                e1002).
academia(aca_soft,  "Academia de Ingeniería de Software",  [c_ingsoft, c_ads, c_progvis, c_web, c_movil], e1003).
academia(aca_redes, "Academia de Redes y Seguridad",       [c_redes1, c_redes2, c_seguridad],             e1004).
academia(aca_mat,   "Academia de Matemáticas Aplicadas",   [c_metnum, c_calculo],                         e1006).

% proyecto(Id, Nombre, Objetivo, Entregables, Lider, Integrantes, Inicio, Fin)
proyecto(p_tutor, "Tutor Inteligente para Métodos Numéricos",
         "Desarrollar un agente pedagógico que asista en la resolución interactiva de algoritmos numéricos.",
         ["Prototipo de software", "Artículo en congreso indexado", "Manual didáctico"],
         e1006, [e1006, e1001, e1008], "2026-02-01", "2027-06-30").

proyecto(p_sigfci, "Sistema de Gestión Académica FCI",
         "Automatizar la asignación docente, control de proyectos y seguimiento curricular en la FCI.",
         ["Especificación SRS", "Plataforma web", "Base de datos transaccional"],
         e1003, [e1003, e1005], "2026-08-01", "2027-07-31").

proyecto(p_ciber, "Diagnóstico de Ciberseguridad en PyMEs del Carmen",
         "Evaluar vulnerabilidades y postura defensiva en pequeñas y medianas empresas de la región.",
         ["Instrumento de evaluación", "Reporte técnico de auditoría"],
         e1007, [e1007, e1004], "2025-09-01", "2026-08-31").

% curso(Id, Creditos, Nombre, Objetivo, IdAcademia)
curso(c_ia,          8, "Inteligencia Artificial",          "Aplicar búsqueda heurística y representación del conocimiento.", aca_ia).
curso(c_sistexp,     6, "Sistemas Expertos",                "Diseñar sistemas basados en reglas e inferencia lógica.",         aca_ia).
curso(c_aprendizaje, 8, "Aprendizaje Automático",           "Entrenar y evaluar modelos predictivos de Machine Learning.",     aca_ia).
curso(c_prolog,      6, "Programación Lógica y Funcional",  "Resolver problemas bajo paradigmas declarativos con Prolog.",      aca_ia).
curso(c_bd1,         8, "Bases de Datos I",                 "Diseñar esquemas relacionales y consultas estructuradas SQL.",    aca_bd).
curso(c_bd2,         8, "Bases de Datos II",                "Optimizar motores transaccionales, índices y bases NoSQL.",       aca_bd).
curso(c_ingsoft,     8, "Ingeniería de Software",           "Aplicar metodologías ágiles y tradicionales de desarrollo.",      aca_soft).
curso(c_ads,         8, "Análisis y Diseño de Sistemas",    "Modelar requerimientos de software mediante UML y Casos de Uso.", aca_soft).
curso(c_progvis,     8, "Programación Visual",              "Construir interfaces gráficas de usuario basadas en eventos.",    aca_soft).
curso(c_web,         8, "Desarrollo Web",                   "Desarrollar plataformas cliente-servidor full-stack escalables.", aca_soft).
curso(c_movil,       6, "Desarrollo Móvil",                 "Construir aplicaciones para dispositivos Android e iOS.",         aca_soft).
curso(c_redes1,      8, "Redes de Computadoras I",          "Configurar topologías de red de área local y protocolos TCP/IP.",  aca_redes).
curso(c_redes2,      8, "Redes de Computadoras II",         "Diseñar direccionamiento y enrutamiento dinámico en redes WAN.",  aca_redes).
curso(c_seguridad,   6, "Seguridad Informática",            "Implementar criptografía y auditoría de seguridad defensiva.",    aca_redes).
curso(c_metnum,      8, "Métodos Numéricos",                "Aproximar raíces, interpolación y resolución numérica computacional.", aca_mat).
curso(c_calculo,     8, "Cálculo Diferencial e Integral",   "Aplicar fundamentos del cálculo al modelado computacional.",      aca_mat).

% curso_capacitacion(Id, Nombre, Objetivo, Horas, Inicio, Fin)
curso_capacitacion(cap_ml,     "Machine Learning con Python y Scikit-Learn",
                   "Construir pipelines de modelos supervisados y no supervisados.", 40, "2026-11-09", "2026-12-04").
curso_capacitacion(cap_cloud,  "Bases de Datos Distribuidas en la Nube",
                   "Desplegar arquitecturas de alta disponibilidad en AWS y GCP.",    30, "2026-11-16", "2026-12-11").
curso_capacitacion(cap_hack,   "Hacking Ético y Pruebas de Penetración",
                   "Ejecutar pruebas de penetración y remediación de incidentes.",    40, "2027-01-11", "2027-02-12").
curso_capacitacion(cap_modelo, "Formación Docente en el Modelo por Competencias UNACAR",
                   "Diseñar secuencias didácticas y rúbricas bajo el modelo UNACAR.", 20, "2026-12-07", "2026-12-11").
curso_capacitacion(cap_scrum,  "Certificación Scrum Master en Entornos Universitarios",
                   "Gestionar proyectos académicos con marcos de trabajo ágiles.",   25, "2026-03-02", "2026-03-27").

% expediente_docente(IdProfesor, GradosList, AcreditacionesList, CapacitacionesTomadasList)
expediente_docente(e1001,
    [grado(licenciatura, "Licenciatura en Informática", "UNACAR", 2002),
     grado(maestria, "Maestría en Ciencias Computacionales", "CINVESTAV", 2006),
     grado(doctorado, "Doctorado en Inteligencia Artificial", "UV", 2011)],
    [acreditacion("Perfil Deseable PRODEP", "SEP", 2023),
     acreditacion("SNII Nivel I", "SECIHTI", 2024)],
    [cap_ml, cap_scrum, cap_modelo]).

expediente_docente(e1002,
    [grado(licenciatura, "Ingeniería en Sistemas Computacionales", "IT Chetumal", 2008),
     grado(maestria, "Maestría en Tecnologías de Información", "UADY", 2013)],
    [acreditacion("Oracle Database SQL Certified Associate", "Oracle", 2022)],
    [cap_cloud, cap_modelo]).

expediente_docente(e1003,
    [grado(licenciatura, "Licenciatura en Informática", "UNACAR", 2005),
     grado(maestria, "Maestría en Ingeniería de Software", "CIMAT", 2009),
     grado(doctorado, "Doctorado en Ciencias Computacionales", "UNAM", 2015)],
    [acreditacion("Perfil Deseable PRODEP", "SEP", 2022),
     acreditacion("Professional Scrum Master I", "Scrum.org", 2023)],
    [cap_scrum, cap_modelo]).

expediente_docente(e1004,
    [grado(licenciatura, "Ingeniería en Telecomunicaciones", "IPN", 2007),
     grado(maestria, "Maestría en Redes y Sistemas Distribuidos", "UDLAP", 2012)],
    [acreditacion("Cisco Certified Network Associate (CCNA)", "Cisco", 2021)],
    [cap_hack, cap_modelo]).

expediente_docente(e1005,
    [grado(licenciatura, "Ingeniería en Sistemas Computacionales", "UNACAR", 2016)],
    [],
    [cap_scrum, cap_modelo]).

expediente_docente(e1006,
    [grado(licenciatura, "Licenciatura en Matemáticas", "UADY", 2001),
     grado(maestria, "Maestría en Matemáticas Aplicadas", "CIMAT", 2004),
     grado(doctorado, "Doctorado en Ciencias (Optimización)", "UNAM", 2009)],
    [acreditacion("Perfil Deseable PRODEP", "SEP", 2020),
     acreditacion("SNII Nivel I", "SECIHTI", 2023)],
    [cap_ml, cap_modelo]).

expediente_docente(e1007,
    [grado(licenciatura, "Licenciatura en Informática", "UNACAR", 2010),
     grado(maestria, "Maestría en Seguridad de la Información", "UNIR", 2018)],
    [acreditacion("CompTIA Security+", "CompTIA", 2023)],
    [cap_hack, cap_modelo]).

expediente_docente(e1008,
    [grado(licenciatura, "Ingeniería en Computación", "UNACAR", 2012),
     grado(maestria, "Maestría en Ciencia de Datos", "ITESM", 2019)],
    [acreditacion("Perfil Deseable PRODEP", "SEP", 2024)],
    [cap_ml, cap_scrum, cap_modelo]).

% asignaciones que ya existen desde el inicio (datos de prueba)
asignacion_academia(e1002, aca_bd).
asignacion_academia(e1003, aca_soft).
asignacion_academia(e1004, aca_redes).
asignacion_academia(e1006, aca_mat).

asignacion_ca(e1003, ca_isd).
asignacion_ca(e1004, ca_rsc).

asignacion_proyecto(e1006, p_tutor).
asignacion_proyecto(e1001, p_tutor).
asignacion_proyecto(e1008, p_tutor).
asignacion_proyecto(e1003, p_sigfci).
asignacion_proyecto(e1005, p_sigfci).
asignacion_proyecto(e1007, p_ciber).
asignacion_proyecto(e1004, p_ciber).

asignacion_curso(e1002, c_bd1).


% --- REGLAS Y AUXILIARES ---

% normalizar ids: a veces llegan como string y a veces como atomo, esto lo arregla
normalizar_id(Val, Atom) :-
    (   atom(Val)
    ->  Atom = Val
    ;   string(Val)
    ->  atom_string(Atom, Val)
    ;   term_to_atom(Val, Atom)
    ).

% relacion entre capacitaciones y academias
capacitacion_academia(cap_ml,    aca_ia).
capacitacion_academia(cap_cloud, aca_bd).
capacitacion_academia(cap_scrum, aca_soft).
capacitacion_academia(cap_hack,  aca_redes).
capacitacion_academia(cap_modelo, aca_ia).

% que areas necesita cada proyecto
proyecto_area(p_tutor,  inteligencia_artificial).
proyecto_area(p_tutor,  matematicas).
proyecto_area(p_sigfci, ingenieria_software).
proyecto_area(p_sigfci, bases_datos).
proyecto_area(p_sigfci, desarrollo_web).
proyecto_area(p_ciber,  redes).
proyecto_area(p_ciber,  ciberseguridad).

% areas que cubre cada capacitacion
capacitacion_area(cap_ml,    inteligencia_artificial).
capacitacion_area(cap_cloud, bases_datos).
capacitacion_area(cap_cloud, desarrollo_web).
capacitacion_area(cap_hack,  ciberseguridad).
capacitacion_area(cap_hack,  redes).
capacitacion_area(cap_scrum, ingenieria_software).
capacitacion_area(cap_modelo, educacion).

% afinidades entre areas (para checar si un profe puede entrar a algo relacionado)
afinidad_area(A, A) :- !.
afinidad_area(inteligencia_artificial, matematicas).
afinidad_area(matematicas,             inteligencia_artificial).
afinidad_area(bases_datos,             ingenieria_software).
afinidad_area(desarrollo_web,          ingenieria_software).
afinidad_area(ciberseguridad,          redes).
afinidad_area(redes,                   ciberseguridad).

% que capacitaciones sirven para que cursos
capacitacion_afin_curso(cap_ml,    c_ia).
capacitacion_afin_curso(cap_ml,    c_sistexp).
capacitacion_afin_curso(cap_ml,    c_aprendizaje).
capacitacion_afin_curso(cap_ml,    c_prolog).
capacitacion_afin_curso(cap_ml,    c_metnum).
capacitacion_afin_curso(cap_cloud, c_bd1).
capacitacion_afin_curso(cap_cloud, c_bd2).
capacitacion_afin_curso(cap_scrum, c_ingsoft).
capacitacion_afin_curso(cap_scrum, c_ads).
capacitacion_afin_curso(cap_scrum, c_web).
capacitacion_afin_curso(cap_hack,  c_redes1).
capacitacion_afin_curso(cap_hack,  c_redes2).
capacitacion_afin_curso(cap_hack,  c_seguridad).

% perfiles que justifican tomar cada capacitacion
perfil_necesita_actualizacion(cap_ml,
    [inteligencia_artificial, matematicas, bases_datos, desarrollo_web, ingenieria_software],
    "Actualización curricular en arquitecturas predictivas y Machine Learning").
perfil_necesita_actualizacion(cap_cloud,
    [bases_datos, desarrollo_web, ingenieria_software, redes],
    "Actualización tecnológica en escalabilidad y bases de datos en la nube").
perfil_necesita_actualizacion(cap_hack,
    [redes, ciberseguridad, desarrollo_web],
    "Actualización en ciberseguridad ofensiva, forense y pentesting").
perfil_necesita_actualizacion(cap_scrum,
    [ingenieria_software, desarrollo_web, bases_datos, inteligencia_artificial],
    "Actualización metodológica en marcos de trabajo ágiles").
perfil_necesita_actualizacion(cap_modelo,
    [inteligencia_artificial, bases_datos, ingenieria_software, redes, ciberseguridad, desarrollo_web, matematicas],
    "Alineación docente al modelo institucional por competencias UNACAR").

% checar si el profe ya tomo la capacitacion (en expediente o ya inscrito)
profesor_tomo_capacitacion(ProfId, CapId) :-
    expediente_docente(ProfId, _, _, Caps),
    member(CapId, Caps).
profesor_tomo_capacitacion(ProfId, CapId) :-
    asignacion_capacitacion(ProfId, CapId).

% buscar si tiene PRODEP en sus acreditaciones
profesor_tiene_prodep(ProfId) :-
    expediente_docente(ProfId, _, Acreditaciones, _),
    member(acreditacion(Nombre, _, _), Acreditaciones),
    sub_atom(Nombre, _, _, _, 'PRODEP').


% --- MOTOR DE INFERENCIA ---
% aqui van las reglas para decidir si un profe puede o no ser asignado

% regla 1: para asignar a academia
% el profe debe dominar al menos una materia de la academia
% o haber tomado una capacitacion relacionada
apto_academia(ProfId, AcaId, MateriasAportadas, Motivo) :-
    profesor(ProfId, _, _, _, CursosDominados),
    academia(AcaId, _, MateriasAca, _),
    findall(M, (member(M, MateriasAca), member(M, CursosDominados)), MateriasAportadas),
    (   MateriasAportadas \= []
    ->  Motivo = "Domina materias adscritas al plan de la academia"
    ;   profesor_tomo_capacitacion(ProfId, CapId),
        capacitacion_academia(CapId, AcaId)
    ->  format(string(Motivo), "Cuenta con capacitación vinculada a la academia (~w)", [CapId])
    ).

% regla 2: para cuerpo academico
% necesita posgrado (maestria o doctorado) y que su especialidad este relacionada
apto_cuerpo_academico(ProfId, CaId, Grado, TieneProdep, Motivo) :-
    profesor(ProfId, _, Grado, Especialidad, _),
    member(Grado, [maestria, doctorado]),
    cuerpo_academico(CaId, _, Linea, _, _),
    afinidad_area(Especialidad, Linea),
    (   profesor_tiene_prodep(ProfId)
    ->  TieneProdep = true,
        Motivo = "Cumple con posgrado, afinidad de línea y bonificación por Perfil PRODEP"
    ;   TieneProdep = false,
        Motivo = "Cumple con grado de posgrado y afinidad temática con la línea de investigación"
    ).

% regla 3: para proyecto
% su especialidad o alguna capacitacion que tomo debe cubrir el area del proyecto
apto_proyecto(ProfId, ProyId, Motivo) :-
    profesor(ProfId, _, _, Especialidad, _),
    proyecto_area(ProyId, AreaProyecto),
    afinidad_area(Especialidad, AreaProyecto),
    !,
    format(string(Motivo), "Especialidad (~w) cubre el área técnica del proyecto (~w)", [Especialidad, AreaProyecto]).

apto_proyecto(ProfId, ProyId, Motivo) :-
    proyecto_area(ProyId, AreaProyecto),
    profesor_tomo_capacitacion(ProfId, CapId),
    capacitacion_area(CapId, AreaCap),
    afinidad_area(AreaCap, AreaProyecto),
    !,
    format(string(Motivo), "Capacitación acreditada (~w) capacita al profesor en el área del proyecto (~w)", [CapId, AreaProyecto]).

% regla 4: calcular el mejor profe para un curso
% se calcula un puntaje con:
%   - posicion en la lista de cursos dominados (pos 1 = 50pts, pos 2 = 40, etc)
%   - grado academico (doctorado=30, maestria=20, licenciatura=10)
%   - si tiene capacitacion afin al curso (+15)
puntos_grado(doctorado,    30).
puntos_grado(maestria,     20).
puntos_grado(licenciatura, 10).

puntos_posicion(Pos, PtsPos) :-
    PtsPos is max(10, 60 - (Pos * 10)).

evaluar_candidato_curso(ProfId, CursoId, PuntajeTotal, DesgloseDict) :-
    curso(CursoId, _, _, _, _),
    profesor(ProfId, _, Grado, _, CursosDominados),
    nth1(Pos, CursosDominados, CursoId),
    puntos_posicion(Pos, PtsPos),
    puntos_grado(Grado, PtsGrado),
    (   profesor_tomo_capacitacion(ProfId, CapAfin),
        capacitacion_afin_curso(CapAfin, CursoId)
    ->  PtsCap = 15,
        CapNombre = CapAfin
    ;   PtsCap = 0,
        CapNombre = "ninguna"
    ),
    PuntajeTotal is PtsPos + PtsGrado + PtsCap,
    DesgloseDict = _{
        posicion: Pos,
        puntos_posicion: PtsPos,
        grado: Grado,
        puntos_grado: PtsGrado,
        capacitacion_afin: CapNombre,
        puntos_capacitacion: PtsCap
    }.

ranking_profesores_curso(CursoId, RankingOrdenado) :-
    findall(Puntaje-(ProfId, DesgloseDict),
            evaluar_candidato_curso(ProfId, CursoId, Puntaje, DesgloseDict),
            Candidatos),
    Candidatos \= [],
    keysort(Candidatos, Ascendente),
    reverse(Ascendente, RankingOrdenado).

mejor_profesor_curso(CursoId, MejorProf, MaxPuntaje, DesgloseDict) :-
    ranking_profesores_curso(CursoId, [MaxPuntaje-(MejorProf, DesgloseDict) | _]).

% regla 5: para inscribir a capacitacion
% que no la haya tomado ya y que su especialidad justifique tomarla
apto_capacitacion(ProfId, CapId, Motivo) :-
    profesor(ProfId, _, _, Especialidad, _),
    perfil_necesita_actualizacion(CapId, PerfilesAceptados, Justificacion),
    member(Especialidad, PerfilesAceptados),
    format(string(Motivo), "~w (Especialidad docente: ~w)", [Justificacion, Especialidad]).


% --- ENDPOINTS REST ---
% rutas de la api
:- http_handler('/api/asignar/academia',         handle_asignar_academia,         [method(post)]).
:- http_handler('/api/asignar/cuerpo-academico', handle_asignar_cuerpo_academico, [method(post)]).
:- http_handler('/api/asignar/proyecto',         handle_asignar_proyecto,         [method(post)]).
:- http_handler('/api/curso/mejor-profesor',     handle_mejor_profesor_curso,     [method(get)]).
:- http_handler('/api/asignar/capacitacion',     handle_asignar_capacitacion,     [method(post)]).
:- http_handler('/api/profesor/asignaciones',    handle_profesor_asignaciones,    [method(get)]).

% endpoint 1 - asignar profe a academia
handle_asignar_academia(Request) :-
    catch(http_read_json_dict(Request, Body), _Err, Body = invalid),
    (   Body == invalid
    ->  reply_json_dict(_{status: "error", code: 400, message: "JSON malformado o vacío"}, [status(400)])
    ;   (   get_dict(profesor_id, Body, RawProf),
            get_dict(academia_id, Body, RawAca)
        ->  normalizar_id(RawProf, ProfId),
            normalizar_id(RawAca, AcaId),
            (   \+ profesor(ProfId, _, _, _, _)
            ->  reply_json_dict(_{status: "error", code: 404, message: "El profesor indicado no existe"}, [status(404)])
            ;   \+ academia(AcaId, _, _, _)
            ->  reply_json_dict(_{status: "error", code: 404, message: "La academia indicada no existe"}, [status(404)])
            ;   asignacion_academia(ProfId, AcaId)
            ->  reply_json_dict(_{status: "error", code: 409, message: "El profesor ya se encuentra asignado a esta academia"}, [status(409)])
            ;   apto_academia(ProfId, AcaId, MateriasAportadas, Motivo)
            ->  assertz(asignacion_academia(ProfId, AcaId)),
                reply_json_dict(_{
                    status: "success",
                    code: 200,
                    message: "Profesor asignado exitosamente a la academia",
                    profesor_id: ProfId,
                    academia_id: AcaId,
                    materias_aportadas: MateriasAportadas,
                    motivo: Motivo
                }, [status(200)])
            ;   reply_json_dict(_{status: "error", code: 400, message: "El profesor no cuenta con materias afines ni capacitaciones para esta academia"}, [status(400)])
            )
        ;   reply_json_dict(_{status: "error", code: 400, message: "Faltan los campos requeridos: profesor_id, academia_id"}, [status(400)])
        )
    ).

% endpoint 2 - asignar profe a cuerpo academico
handle_asignar_cuerpo_academico(Request) :-
    catch(http_read_json_dict(Request, Body), _Err, Body = invalid),
    (   Body == invalid
    ->  reply_json_dict(_{status: "error", code: 400, message: "JSON malformado o vacío"}, [status(400)])
    ;   (   get_dict(profesor_id, Body, RawProf),
            get_dict(ca_id, Body, RawCa)
        ->  normalizar_id(RawProf, ProfId),
            normalizar_id(RawCa, CaId),
            (   \+ profesor(ProfId, _, _, _, _)
            ->  reply_json_dict(_{status: "error", code: 404, message: "El profesor indicado no existe"}, [status(404)])
            ;   \+ cuerpo_academico(CaId, _, _, _, _)
            ->  reply_json_dict(_{status: "error", code: 404, message: "El Cuerpo Académico indicado no existe"}, [status(404)])
            ;   asignacion_ca(ProfId, CaId)
            ->  reply_json_dict(_{status: "error", code: 409, message: "El profesor ya se encuentra asignado a este Cuerpo Académico"}, [status(409)])
            ;   profesor(ProfId, _, Grado, _, _),
                \+ member(Grado, [maestria, doctorado])
            ->  reply_json_dict(_{status: "error", code: 400, message: "Se requiere grado de posgrado (maestría o doctorado) para ingresar a un Cuerpo Académico"}, [status(400)])
            ;   apto_cuerpo_academico(ProfId, CaId, GradoDocente, TieneProdep, Motivo)
            ->  assertz(asignacion_ca(ProfId, CaId)),
                reply_json_dict(_{
                    status: "success",
                    code: 200,
                    message: "Profesor incorporado exitosamente al Cuerpo Académico",
                    profesor_id: ProfId,
                    ca_id: CaId,
                    grado: GradoDocente,
                    bonificacion_prodep: TieneProdep,
                    motivo: Motivo
                }, [status(200)])
            ;   reply_json_dict(_{status: "error", code: 400, message: "La especialidad del profesor no es afín a la línea de investigación del Cuerpo Académico"}, [status(400)])
            )
        ;   reply_json_dict(_{status: "error", code: 400, message: "Faltan los campos requeridos: profesor_id, ca_id"}, [status(400)])
        )
    ).

% endpoint 3 - asignar profe a proyecto
handle_asignar_proyecto(Request) :-
    catch(http_read_json_dict(Request, Body), _Err, Body = invalid),
    (   Body == invalid
    ->  reply_json_dict(_{status: "error", code: 400, message: "JSON malformado o vacío"}, [status(400)])
    ;   (   get_dict(profesor_id, Body, RawProf),
            get_dict(proyecto_id, Body, RawProy)
        ->  normalizar_id(RawProf, ProfId),
            normalizar_id(RawProy, ProyId),
            (   \+ profesor(ProfId, _, _, _, _)
            ->  reply_json_dict(_{status: "error", code: 404, message: "El profesor indicado no existe"}, [status(404)])
            ;   \+ proyecto(ProyId, _, _, _, _, _, _, _)
            ->  reply_json_dict(_{status: "error", code: 404, message: "El proyecto indicado no existe"}, [status(404)])
            ;   ( asignacion_proyecto(ProfId, ProyId) ; (proyecto(ProyId, _, _, _, _, IntegrantesActuales, _, _), member(ProfId, IntegrantesActuales)) )
            ->  reply_json_dict(_{status: "error", code: 409, message: "El profesor ya figura como integrante activo en este proyecto"}, [status(409)])
            ;   apto_proyecto(ProfId, ProyId, Motivo)
            ->  assertz(asignacion_proyecto(ProfId, ProyId)),
                retract(proyecto(ProyId, Nom, Obj, Ent, Lider, IntegrantesViejos, Ini, Fin)),
                ( member(ProfId, IntegrantesViejos) -> IntegrantesNuevos = IntegrantesViejos ; IntegrantesNuevos = [ProfId|IntegrantesViejos] ),
                assertz(proyecto(ProyId, Nom, Obj, Ent, Lider, IntegrantesNuevos, Ini, Fin)),
                reply_json_dict(_{
                    status: "success",
                    code: 200,
                    message: "Profesor asignado exitosamente al proyecto",
                    profesor_id: ProfId,
                    proyecto_id: ProyId,
                    justificacion_perfil: Motivo,
                    integrantes_actualizados: IntegrantesNuevos
                }, [status(200)])
            ;   reply_json_dict(_{status: "error", code: 400, message: "El perfil o capacitaciones del profesor no cubren los requerimientos técnicos del proyecto"}, [status(400)])
            )
        ;   reply_json_dict(_{status: "error", code: 400, message: "Faltan los campos requeridos: profesor_id, proyecto_id"}, [status(400)])
        )
    ).

% endpoint 4 - obtener el mejor profe para un curso dado
handle_mejor_profesor_curso(Request) :-
    catch(
        http_parameters(Request, [id(RawId, [string])]),
        _Err,
        RawId = missing
    ),
    (   RawId == missing
    ->  reply_json_dict(_{status: "error", code: 400, message: "Falta el parámetro de consulta 'id' del curso"}, [status(400)])
    ;   normalizar_id(RawId, CursoId),
        (   \+ curso(CursoId, _, _, _, _)
        ->  reply_json_dict(_{status: "error", code: 404, message: "El curso solicitado no existe"}, [status(404)])
        ;   curso(CursoId, _, NombreCurso, _, _),
            (   mejor_profesor_curso(CursoId, MejorProf, PuntajeMax, Desglose)
            ->  profesor(MejorProf, NombreProf, _, _, _),
                reply_json_dict(_{
                    status: "success",
                    code: 200,
                    curso: CursoId,
                    nombre_curso: NombreCurso,
                    mejor_profesor: MejorProf,
                    nombre_profesor: NombreProf,
                    puntaje_total: PuntajeMax,
                    desglose: Desglose
                }, [status(200)])
            ;   reply_json_dict(_{status: "error", code: 400, message: "No existen profesores registrados que dominen este curso"}, [status(400)])
            )
        )
    ).

% endpoint 5 - inscribir profe a capacitacion
handle_asignar_capacitacion(Request) :-
    catch(http_read_json_dict(Request, Body), _Err, Body = invalid),
    (   Body == invalid
    ->  reply_json_dict(_{status: "error", code: 400, message: "JSON malformado o vacío"}, [status(400)])
    ;   (   get_dict(profesor_id, Body, RawProf),
            get_dict(capacitacion_id, Body, RawCap)
        ->  normalizar_id(RawProf, ProfId),
            normalizar_id(RawCap, CapId),
            (   \+ profesor(ProfId, _, _, _, _)
            ->  reply_json_dict(_{status: "error", code: 404, message: "El profesor indicado no existe"}, [status(404)])
            ;   \+ curso_capacitacion(CapId, _, _, _, _, _)
            ->  reply_json_dict(_{status: "error", code: 404, message: "El curso de capacitación indicado no existe"}, [status(404)])
            ;   asignacion_capacitacion(ProfId, CapId)
            ->  reply_json_dict(_{status: "error", code: 409, message: "El profesor ya se encuentra inscrito en este curso de capacitación"}, [status(409)])
            ;   expediente_docente(ProfId, _, _, CapsAcreditadas), member(CapId, CapsAcreditadas)
            ->  reply_json_dict(_{status: "error", code: 400, message: "El profesor ya acreditó previamente este curso de capacitación en su expediente"}, [status(400)])
            ;   apto_capacitacion(ProfId, CapId, Motivo)
            ->  assertz(asignacion_capacitacion(ProfId, CapId)),
                reply_json_dict(_{
                    status: "success",
                    code: 200,
                    message: "Profesor inscrito exitosamente en la capacitación",
                    profesor_id: ProfId,
                    capacitacion_id: CapId,
                    justificacion_actualizacion: Motivo
                }, [status(200)])
            ;   reply_json_dict(_{status: "error", code: 400, message: "La especialidad del profesor no justifica la necesidad de actualización para este tema"}, [status(400)])
            )
        ;   reply_json_dict(_{status: "error", code: 400, message: "Faltan los campos requeridos: profesor_id, capacitacion_id"}, [status(400)])
        )
    ).

% endpoint 6 - ver todas las asignaciones de un profe
handle_profesor_asignaciones(Request) :-
    catch(
        http_parameters(Request, [id(RawId, [string])]),
        _Err,
        RawId = missing
    ),
    (   RawId == missing
    ->  reply_json_dict(_{status: "error", code: 400, message: "Falta el parámetro de consulta 'id' del profesor"}, [status(400)])
    ;   normalizar_id(RawId, ProfId),
        (   \+ profesor(ProfId, _, _, _, _)
        ->  reply_json_dict(_{status: "error", code: 404, message: "Profesor no encontrado"}, [status(404)])
        ;   profesor(ProfId, Nombre, Grado, Especialidad, CursosDominados),
            (   expediente_docente(ProfId, GradosRaw, AcredRaw, CapsTomadas)
            ->  findall(_{nivel: N, titulo: T, institucion: I, anio: A},
                        member(grado(N, T, I, A), GradosRaw), GradosDicts),
                findall(_{nombre: NomA, organismo: Org, anio: AnioA},
                        member(acreditacion(NomA, Org, AnioA), AcredRaw), AcredDicts)
            ;   GradosDicts = [],
                AcredDicts = [],
                CapsTomadas = []
            ),
            % Recopilación de asignaciones dinámicas activas
            findall(Aca,   asignacion_academia(ProfId, Aca),   AcademiasAsignadas),
            findall(Ca,    asignacion_ca(ProfId, Ca),         CAsAsignados),
            findall(Proy,  asignacion_proyecto(ProfId, Proy), ProyectosAsignados),
            findall(Curso, asignacion_curso(ProfId, Curso),   CursosAsignados),
            findall(Cap,   asignacion_capacitacion(ProfId, Cap), CapsInscritas),
            reply_json_dict(_{
                status: "success",
                code: 200,
                profesor: _{
                    id: ProfId,
                    nombre: Nombre,
                    grado: Grado,
                    especialidad: Especialidad,
                    cursos_dominados: CursosDominados
                },
                expediente: _{
                    grados: GradosDicts,
                    acreditaciones: AcredDicts,
                    capacitaciones_tomadas: CapsTomadas
                },
                asignaciones: _{
                    academias: AcademiasAsignadas,
                    cuerpos_academicos: CAsAsignados,
                    proyectos: ProyectosAsignados,
                    cursos: CursosAsignados,
                    capacitaciones: CapsInscritas
                }
            }, [status(200)])
        )
    ).


% --- ARRANQUE Y PARO DEL SERVIDOR ---

% iniciar en el puerto que se pase como argumento
iniciar_servidor(Puerto) :-
    (   servidor_activo(PuertoActivo)
    ->  format('El servidor ya se encuentra ejecutandose en el puerto ~w~n', [PuertoActivo])
    ;   http_server(http_dispatch, [port(Puerto)]),
        assertz(servidor_activo(Puerto)),
        format('=================================================================~n'),
        format('  Servidor SWI-Prolog REST (FCI-UNACAR) activo en el puerto ~w~n', [Puerto]),
        format('  URL Base: http://localhost:~w/~n', [Puerto]),
        format('=================================================================~n')
    ).

% detener el servidor
detener_servidor :-
    (   servidor_activo(Puerto)
    ->  http_stop_server(Puerto, []),
        retractall(servidor_activo(_)),
        format('Servidor en el puerto ~w detenido exitosamente.~n', [Puerto])
    ;   writeln('No hay ningún servidor activo para detener.')
    ).

% loop para mantener el servidor corriendo
mantener_servidor :-
    repeat,
    sleep(1),
    (   servidor_activo(_)
    ->  fail
    ;   true
    ).
