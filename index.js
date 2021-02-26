"use strict";

(() => {

window.addEventListener("beforeunload", e => {
    return (e || window.event).returnValue = "Are you sure you want to go?";
});

if (window.location.search == "?no-drag-drop")
    return;

window.basic_interact = {};

let snap;
basic_interact.snap = () => {
    if (!snap)
        snap = interact.modifiers.snap({
            targets: [
                interact.snappers.grid({x: 5, y: 5}),
            ],
            range: Infinity,
            offset: 'self',
            relativePoints: [{x: 0, y: 0}]
        })
    return snap;
};

basic_interact.add = (target, draggable, resizable, callback) => {
    let x = 0;
    let y = 0;
    target.style.touchAction = "none";
    if (target.style.userSelect)
        target.setAttribute("data-old-user-select", target.style.userSelect);
    target.style.userSelect = "none";
    target.classList.add("drag_drop");

    if (resizable)
        target.style.boxSizing = "border-box";

    function move() {
        target.style.transform = `translate(${x}px, ${y}px)`;
    };
    move();

    function endMove() {
        callback.call(target, x, y, target.offsetWidth, target.offsetHeight);
    };

    const interact_target = interact(target).on("tap", () => {
        callback.call(target);
    });

    if (draggable)
        interact_target.draggable({
            // inertia: true,
            listeners: {
                end: endMove,
                move (event) {
                    x += event.dx;
                    y += event.dy;
                    move();
                },
            },
            modifiers: [
                interact.modifiers.restrictRect({
                    restriction: 'parent',
                    endOnly: true,
                }),
                basic_interact.snap()
            ],
        });

    if (resizable)
        interact_target.resizable({
            edges: {
                top: true,
                left: true,
                bottom: true,
                right: true,
            },
            listeners: {
                end: endMove,
                move (event) {
                    target.style.width = `${event.rect.width}px`;
                    target.style.height = `${event.rect.height}px`;
                    x += event.deltaRect.left;
                    y += event.deltaRect.top;
                    move();
                }
            },
            modifiers: [
                // interact.modifiers.restrictRect({
                //     restriction: 'parent',
                //     endOnly: true,
                // }),
                basic_interact.snap()
            ],
            invert: "reposition",
        });
};

basic_interact.remove = target => {
    interact(target).unset();
    target.style.transform = "";
    target.style.touchAction = "";
    const old_user_select = target.getAttribute("data-old-user-select");
    target.style.userSelect = old_user_select || "";
    target.removeAttribute("data-old-user-select");
    target.classList.remove("drag_drop");
    delete basic_interact.target;
};

window.addEventListener("load", () => {
    const elem = document.createElement("style");
    elem.innerHTML = `
        .drag_drop * {
            cursor: inherit;
        }
    `;
    document.head.appendChild(elem);
});

})();
