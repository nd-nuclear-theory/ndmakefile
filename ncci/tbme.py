"""tbme.py -- task handlers for MFDn runs.

Patrick Fasano
University of Notre Dame

- 03/22/17 (pjf): Created, split from __init__.py.
- 04/06/17 (pjf): Correctly reference config submodule (mfdn.config).
- 04/11/17 (pjf): Fix broken imports.
- 06/03/17 (pjf):
  + Remove explicit references to natural orbitals from bulk of scripting.
  + Fix VC scaling.
- 06/07/17 (pjf): Clean up style.
- 08/11/17 (pjf): Use new TruncationModes.
- 08/26/17 (pjf): Add support for general truncation schemes.
- 09/12/17 (pjf): Update for config -> modes + environ split.
- 09/20/17 (pjf): Add isospin operators.
- 09/22/17 (pjf): Take "observables" as list of tuples instead of dict.
- 10/18/17 (pjf): Use separate work directory for each postfix.
- 10/25/17 (pjf): Rename "observables" to "tb_observables".
- 03/15/19 (pjf): Rough in support for arbitrary two-body operators.
"""
import collections
import os

import mcscript.utils

from . import (
    utils,
    modes,
    environ,
    operators,
)


def generate_tbme(task, postfix=""):
    """Generate TBMEs for MFDn run.

    Arguments:
        task (dict): as described in module docstring
        postfix (string, optional): identifier added to input filenames
    """
    # extract parameters for convenience
    A = sum(task["nuclide"])
    a_cm = task["a_cm"]
    hw = task["hw"]
    hw_cm = task.get("hw_cm")
    if (hw_cm is None):
        hw_cm = hw
    hw_int = task["hw_int"]
    hw_coul = task["hw_coul"]
    hw_coul_rescaled = task.get("hw_coul_rescaled")
    if (hw_coul_rescaled is None):
        hw_coul_rescaled = hw
    xform_truncation_int = task.get("xform_truncation_int")
    if (xform_truncation_int is None):
        xform_truncation_int = task["truncation_int"]
    xform_truncation_coul = task.get("xform_truncation_coul")
    if (xform_truncation_coul is None):
        xform_truncation_coul = task["truncation_coul"]

    # sanity check on hw
    if (task["basis_mode"] is modes.BasisMode.kDirect) and (hw != hw_int):
        raise mcscript.exception.ScriptError(
            "Using basis mode {} but hw = {} and hw_int = {}".format(
                task["basis_mode"], hw, hw_int
            ))

    # accumulate h2mixer targets
    targets = collections.OrderedDict()

    # target: Hamiltonian
    if (task.get("hamiltonian")):
        targets["tbme-H"] = task["hamiltonian"]
    else:
        targets["tbme-H"] = operators.Hamiltonian(
            A=A, hw=hw, a_cm=a_cm, bsqr_intr=hw/hw_cm,
            use_coulomb=task["use_coulomb"], bsqr_coul=hw_coul_rescaled/hw_coul
        )

    # accumulate observables
    if task.get("tb_observables"):
        for (basename, operator) in task["tb_observables"]:
            targets["tbme-{}".format(basename)] = operators.TwoBodyOperator(operator)

    # target: radius squared
    if "tbme-rrel2" not in targets:
        targets["tbme-rrel2"] = operators.rrel2(A, hw)

    # target: Ncm
    if "tbme-Ncm" not in targets:
        targets["tbme-Ncm"] = operators.Ncm(A, hw/hw_cm)

    # optional observable sets
    # Hamiltonian components
    if "H-components" in task["observable_sets"]:
        # target: Trel (diagnostic)
        targets["tbme-Trel"] = operators.Trel(A, hw)
        # target: Tcm (diagnostic)
        targets["tbme-Tcm"] = operators.Tcm(A, hw)
        # target: VNN (diagnostic)
        targets["tbme-VNN"] = operators.VNN()
        # target: VC (diagnostic)
        if (task["use_coulomb"]):
            targets["tbme-VC"] = operators.VC(hw_coul_rescaled/hw_coul)
    # squared angular momenta
    if ("am-sqr" in task["observable_sets"]):
        targets["tbme-L2"] = operators.L2()
        targets["tbme-Sp2"] = operators.Sp2()
        targets["tbme-Sn2"] = operators.Sn2()
        targets["tbme-S2"] = operators.S2()
        targets["tbme-J2"] = operators.J2()
    if ("isospin" in task["observable_sets"]):
        targets["tbme-T2"] = operators.T2()

    # get set of required sources
    required_sources = set()
    required_sources.update(*[op.keys() for op in targets.values()])

    # accumulate h2mixer input lines
    lines = []

    # initial comment
    lines.append("# task: {}".format(task))
    lines.append("")

    # global mode definitions
    target_truncation = task.get("target_truncation")
    if target_truncation is None:
        # automatic derivation
        truncation_parameters = task["truncation_parameters"]
        if task["sp_truncation_mode"] is modes.SingleParticleTruncationMode.kNmax:
            if task["mb_truncation_mode"] is modes.ManyBodyTruncationMode.kNmax:
                # important: truncation of orbitals file, one-body
                # truncation of interaction file, and MFDn
                # single-particle shells (beware 1-based) must agree
                N1_max = truncation_parameters["Nv"]+truncation_parameters["Nmax"]
                N2_max = 2*truncation_parameters["Nv"]+truncation_parameters["Nmax"]
                target_weight_max = utils.weight_max_string((N1_max, N2_max))
            elif task["mb_truncation_mode"] == modes.ManyBodyTruncationMode.kFCI:
                N1_max = truncation_parameters["Nmax"]
                target_weight_max = utils.weight_max_string(("ob", N1_max))
            else:
                raise mcscript.exception.ScriptError(
                    "invalid mb_truncation_mode {}".format(task["mb_truncation_mode"])
                )
        else:
            if task["mb_truncation_mode"] is modes.ManyBodyTruncationMode.kFCI:
                w1_max = truncation_parameters["sp_weight_max"]
                target_weight_max = utils.weight_max_string(("ob", w1_max))
            else:
                w1_max = truncation_parameters["sp_weight_max"]
                w2_max = min(truncation_parameters["mb_weight_max"], 2*truncation_parameters["sp_weight_max"])  # TODO this is probably too large
                target_weight_max = utils.weight_max_string((w1_max, w2_max))
    else:
        # given value
        target_weight_max = utils.weight_max_string(target_truncation)
    lines.append("set-target-indexing {orbitals_filename} {target_weight_max}".format(
        orbitals_filename=environ.orbitals_filename(postfix),
        target_weight_max=target_weight_max,
        **task
    ))
    lines.append("set-target-multipolarity 0 0 0")
    lines.append("set-output-format {h2_format}".format(**task))
    lines.append("set-mass {A}".format(A=A, **task))
    lines.append("")

    # radial operator inputs
    for operator_type in ["r", "k"]:
        for power in [1, 2]:
            radial_me_filename = environ.radial_me_filename(postfix, operator_type, power)
            lines.append("define-radial-operator {} {} {}".format(operator_type, power, radial_me_filename))
    lines.append("")

    # pn overlap input
    pn_olap_me_filename = environ.radial_pn_olap_filename(postfix)
    lines.append("define-pn-overlaps {}".format(pn_olap_me_filename))
    lines.append("")

    # sources: h2mixer built-ins
    tbme_sources = {}
    builtin_sources = operators.k_h2mixer_builtin_operators
    for source in sorted((builtin_sources & required_sources)):
        tbme_sources[source] = operators.TwoBodyOperatorSource()

    # sources: VNN
    if "VNN" in required_sources:
        VNN_filename = task.get("interaction_file")
        if VNN_filename is None:
            VNN_filename = environ.interaction_filename(
                task["interaction"],
                task["truncation_int"],
                task["hw_int"]
            )

        if task["basis_mode"] is modes.BasisMode.kDirect:
            tbme_sources["VNN"] = operators.TwoBodyOperatorSource(filename=VNN_filename)
        else:
            tbme_sources["VNN"] = operators.TwoBodyOperatorSource(
                filename=VNN_filename,
                xform_filename=environ.radial_olap_int_filename(postfix),
                xform_truncation=xform_truncation_int
            )

    # sources: Coulomb
    #
    # Note: This is the "unscaled" Coulomb, still awaiting the scaling
    # factor from dilation.
    if "VC_unscaled" in required_sources:
        VC_filename = task.get("coulomb_file")
        if VC_filename is None:
            VC_filename = environ.interaction_filename(
                "VC",
                task["truncation_coul"],
                task["hw_coul"]
            )
        if task["basis_mode"] in (modes.BasisMode.kDirect, modes.BasisMode.kDilated):
            tbme_sources["VC_unscaled"] = operators.TwoBodyOperatorSource(filename=VC_filename)
        else:
            tbme_sources["VC_unscaled"] = operators.TwoBodyOperatorSource(
                filename=VC_filename,
                xform_filename=environ.radial_olap_coul_filename(postfix),
                xform_truncation=xform_truncation_coul
            )

    # sources: override with user-provided
    user_tbme_sources = task.get("tbme_sources")
    if (user_tbme_sources is not None):
        for (id, source) in user_tbme_sources:
            tbme_sources[id] = source

    # sources: generate h2mixer input
    for id in sorted(required_sources):
        lines.append(tbme_sources[id].get_h2mixer_line(id))


    lines.append("")

    # targets: generate h2mixer input
    for (basename, operator) in targets.items():
        lines.append("define-target work{:s}/{:s}.bin".format(postfix, basename))
        for (source, coefficient) in operator.items():
            lines.append("  add-source {:s} {:e}".format(source, coefficient))
        lines.append("")

    # ensure terminal line
    lines.append("")

    # diagnostic: log input lines to file
    #
    # This is purely for easy diagnostic purposes, since lines will be
    # fed directly to h2mixer as stdin below.
    mcscript.utils.write_input(environ.h2mixer_filename(postfix), input_lines=lines, verbose=False)

    # create work directory if it doesn't exist yet (-p)
    mcscript.call(["mkdir", "-p", "work{:s}".format(postfix)])

    # invoke h2mixer
    mcscript.call(
        [
            environ.shell_filename("h2mixer")
        ],
        input_lines=lines,
        mode=mcscript.CallMode.kSerial
    )
